# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    # Configures the OpenTelemetry SDK with Dash0 defaults. Leans on the Ruby
    # SDK's env-driven configurator: once the endpoint/protocol defaults are set
    # and the exporter gems are required, `OpenTelemetry::SDK.configure` wires
    # up the OTLP exporters and processors from the environment. We own the
    # resource. Traces, metrics, and logs are all exported over OTLP/HTTP-protobuf
    # to the same collector base URL (`/v1/traces`, `/v1/metrics`, `/v1/logs`).
    #
    # Metrics and logs support activates simply by requiring their SDK gems: they
    # prepend `ConfiguratorPatch` modules that fill in the otherwise-empty
    # metrics/logs configuration hooks the base SDK calls during `configure`.
    module SdkConfiguration
      # OTLP is only supported over HTTP/protobuf in the Ruby SDK's default path.
      DEFAULT_PROTOCOL = 'http/protobuf'

      # DASH0_DEBUG_PRINT_SPANS=true additionally prints every span to stdout.
      DEBUG_PRINT_SPANS_ENV = 'DASH0_DEBUG_PRINT_SPANS'

      # When the operator/injector mounts a Bundler-less gem bundle, its path is
      # exposed here and the distribution is responsible for putting the bundled
      # gems on the load path itself.
      ADDITIONAL_GEM_PATH_ENV = 'OTEL_RUBY_ADDITIONAL_GEM_PATH'

      # Non-`opentelemetry-*` gems from the bundle that must also be on the load
      # path (OTLP exporter dependencies). Restricting to this set, rather than
      # every gem in the mount, avoids shadowing the application's own gems.
      #
      # Drift gate: this list must cover every non-`opentelemetry-*` gem the SDK
      # closure `require`s at load time in the target's Ruby (excluding default
      # gems that ship with Ruby itself). The injection smoke workflow reproduces
      # that closure — `test/docker/verify.sh` builds the mounted bundle, runs
      # the distribution with `GEM_HOME=/tmp/empty` (no ambient gem environment),
      # and requires the SDK. If a bundle update pulls in a new non-otel dep, the
      # `require` fails there with a `LoadError` and the workflow fails; add the
      # missing gem name here to fix. Keep `Gemfile.lock` in that workflow's path
      # filter so lockfile-only bumps trip the check.
      ADDITIONAL_LIB_GEM_ALLOWLIST = %w[googleapis-common-protos-types google-protobuf].freeze

      module_function

      # @param base_url [String] the Dash0 collector base URL. The generic
      #   `OTEL_EXPORTER_OTLP_ENDPOINT` is used (not a signal-specific variable),
      #   so each exporter appends its own `/v1/{traces,metrics,logs}` path.
      def apply(base_url:)
        configure_exporter_defaults(base_url)
        require_sdk_gems
        resource = build_resource

        ::OpenTelemetry::SDK.configure do |c|
          c.resource = resource
        end

        install_debug_span_printer if Environment.opted_in?(DEBUG_PRINT_SPANS_ENV)
      end

      def configure_exporter_defaults(base_url)
        Environment.set_default('OTEL_EXPORTER_OTLP_ENDPOINT', base_url)
        Environment.set_default('OTEL_EXPORTER_OTLP_PROTOCOL', DEFAULT_PROTOCOL)
      end

      def require_sdk_gems
        wire_additional_gem_path
        require 'opentelemetry-sdk'
        require 'opentelemetry-metrics-sdk'
        require 'opentelemetry-logs-sdk'
        require 'opentelemetry-exporter-otlp'
        require 'opentelemetry-exporter-otlp-metrics'
        require 'opentelemetry-exporter-otlp-logs'
        require 'opentelemetry-resource-detector-container'
        # Populate the instrumentation registry so the installer can sweep it.
        require 'opentelemetry-instrumentation-all'
      end

      # In the injected (Bundler-less) environment the OpenTelemetry gems live only
      # under OTEL_RUBY_ADDITIONAL_GEM_PATH; put their `lib` directories on the load
      # path so the requires above resolve. A no-op when the variable is unset
      # (e.g. running under Bundler, where the gems are already resolvable).
      def wire_additional_gem_path
        gem_path = ENV.fetch(ADDITIONAL_GEM_PATH_ENV, nil)
        return if gem_path.nil? || !Dir.exist?(gem_path)

        Dir.glob(File.join(gem_path, 'gems', '*')).each do |gem_dir|
          next unless on_load_path?(File.basename(gem_dir))

          lib = File.join(gem_dir, 'lib')
          $LOAD_PATH.unshift(lib) if Dir.exist?(lib) && !$LOAD_PATH.include?(lib)
        end
      end

      def on_load_path?(gem_dir_name)
        gem_dir_name.start_with?('opentelemetry-') ||
          ADDITIONAL_LIB_GEM_ALLOWLIST.any? { |name| gem_dir_name.start_with?("#{name}-") }
      end

      # Adds a console span exporter *after* configure. It must not be added inside
      # the configure block: the SDK configurator only builds the env-driven OTLP
      # exporter when no span processor was registered manually, so adding one
      # there would silently disable OTLP export. Appending to the already-built
      # provider keeps OTLP and adds console output alongside it.
      def install_debug_span_printer
        ::OpenTelemetry.tracer_provider.add_span_processor(
          ::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
            ::OpenTelemetry::SDK::Trace::Export::ConsoleSpanExporter.new
          )
        )
      end

      # Builds the resource merged onto the SDK's default resource (process, SDK,
      # and service-name-from-env attributes) by the configurator. Beyond the
      # distro identity, this runs the upstream container detector plus the two
      # custom Dash0 detectors. On key conflicts the later `merge` argument wins;
      # distro attributes are applied last so they always take effect.
      def build_resource
        ::OpenTelemetry::SDK::Resources::Resource.create({})
                                                 .merge(::OpenTelemetry::Resource::Detector::Container.detect)
                                                 .merge(Resource::KubernetesPod.detect)
                                                 .merge(Resource::ServiceNameFallback.detect)
                                                 .merge(Resource::Distribution.detect)
      end
    end
  end
end
