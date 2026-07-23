# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    class SdkConfigurationTest < Minitest::Test
      include TestHelpers

      def test_full_boot_configures_sdk_and_exports_a_span
        result = run_in_subprocess('DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318') do
          require 'dash0-opentelemetry'

          tracer_provider = ::OpenTelemetry.tracer_provider
          resource_attributes = tracer_provider.instance_variable_get(:@resource).instance_variable_get(:@attributes)

          # Attach an in-memory exporter to prove the trace pipeline is wired up.
          exporter = ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
          tracer_provider.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
          tracer_provider.tracer('test-tracer').in_span('test-span') { |span| span.set_attribute('k', 'v') }

          {
            booted: Dash0::OpenTelemetry::Boot.booted?,
            tracer_provider_class: tracer_provider.class.name,
            distro_name: resource_attributes['telemetry.distro.name'],
            distro_version: resource_attributes['telemetry.distro.version'],
            endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil),
            protocol: ENV.fetch('OTEL_EXPORTER_OTLP_PROTOCOL', nil),
            span_names: exporter.finished_spans.map(&:name)
          }
        end

        refute result[:error], result[:error]
        assert result[:booted]
        assert_equal 'OpenTelemetry::SDK::Trace::TracerProvider', result[:tracer_provider_class]
        assert_equal 'dash0-ruby', result[:distro_name]
        assert_equal Dash0::OpenTelemetry::VERSION, result[:distro_version]
        assert_equal 'http://localhost:4318', result[:endpoint]
        assert_equal 'http/protobuf', result[:protocol]
        assert_includes result[:span_names], 'test-span'
      end

      def test_does_not_override_an_explicit_endpoint
        result = run_in_subprocess(
          'DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318',
          'OTEL_EXPORTER_OTLP_ENDPOINT' => 'http://custom:4318'
        ) do
          require 'dash0-opentelemetry'
          { endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil) }
        end

        refute result[:error], result[:error]
        assert_equal 'http://custom:4318', result[:endpoint]
      end
    end
  end
end
