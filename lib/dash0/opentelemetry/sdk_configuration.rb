# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    # Configures the OpenTelemetry SDK with Dash0 defaults. Leans on the Ruby
    # SDK's env-driven configurator: once the endpoint/protocol defaults are set
    # and the exporter gems are required, `OpenTelemetry::SDK.configure` wires
    # up the OTLP exporter and a BatchSpanProcessor from the environment. We own
    # the resource.
    module SdkConfiguration
      # OTLP is only supported over HTTP/protobuf in the Ruby SDK's default path.
      DEFAULT_PROTOCOL = 'http/protobuf'

      module_function

      # @param base_url [String] the Dash0 collector base URL. The generic
      #   `OTEL_EXPORTER_OTLP_ENDPOINT` is used (not a signal-specific variable),
      #   so the exporter appends `/v1/traces` (and, later, `/v1/metrics`,
      #   `/v1/logs`) to it.
      def apply(base_url:)
        configure_exporter_defaults(base_url)
        require_sdk_gems
        resource = build_resource

        ::OpenTelemetry::SDK.configure do |c|
          c.resource = resource
        end
      end

      def configure_exporter_defaults(base_url)
        Environment.set_default('OTEL_EXPORTER_OTLP_ENDPOINT', base_url)
        Environment.set_default('OTEL_EXPORTER_OTLP_PROTOCOL', DEFAULT_PROTOCOL)
      end

      def require_sdk_gems
        require 'opentelemetry-sdk'
        require 'opentelemetry-exporter-otlp'
        # Populate the instrumentation registry so the installer can sweep it.
        require 'opentelemetry-instrumentation-all'
      end

      # The distro resource is merged onto the SDK's default resource (process,
      # SDK, and service-name-from-env attributes) by the configurator.
      def build_resource
        Resource::Distribution.detect
      end
    end
  end
end
