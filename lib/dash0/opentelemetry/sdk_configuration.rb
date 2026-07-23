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
        require 'opentelemetry-sdk'
        require 'opentelemetry-metrics-sdk'
        require 'opentelemetry-logs-sdk'
        require 'opentelemetry-exporter-otlp'
        require 'opentelemetry-exporter-otlp-metrics'
        require 'opentelemetry-exporter-otlp-logs'
        # Populate the instrumentation registry so the installer can sweep it.
        require 'opentelemetry-instrumentation-all'
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

      # The distro resource is merged onto the SDK's default resource (process,
      # SDK, and service-name-from-env attributes) by the configurator.
      def build_resource
        Resource::Distribution.detect
      end
    end
  end
end
