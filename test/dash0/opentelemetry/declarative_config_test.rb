# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    class DeclarativeConfigTest < Minitest::Test
      include TestHelpers

      def test_config_file_boot_installs_the_meter_provider
        result = run_in_subprocess('OTEL_CONFIG_FILE' => write_config_file(<<~YAML)) do
          file_format: "1.0"
          tracer_provider:
            processors:
              - simple:
                  exporter:
                    console: {}
          meter_provider:
            readers:
              - periodic:
                  interval: 60000
                  exporter:
                    otlp_http:
                      endpoint: http://localhost:4318/v1/metrics
        YAML
          require 'dash0-opentelemetry'
          meter_provider = ::OpenTelemetry.meter_provider
          reader = meter_provider.metric_readers.first

          {
            meter_provider_class: meter_provider.class.name,
            reader_class: reader.class.name,
            exporter_class: reader.instance_variable_get(:@exporter).class.name,
            shared_resource: meter_provider.resource.equal?(::OpenTelemetry.tracer_provider.resource)
          }
        end

        refute result[:error], result[:error]
        assert_equal 'OpenTelemetry::SDK::Metrics::MeterProvider', result[:meter_provider_class]
        assert_equal 'OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader', result[:reader_class]
        assert_equal 'OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter', result[:exporter_class]
        assert result[:shared_resource], 'meter and tracer providers must share the configured resource'
      end

      def test_view_with_default_aggregation_records_measurements
        result = run_in_subprocess('OTEL_CONFIG_FILE' => write_config_file(<<~YAML)) do
          file_format: "1.0"
          meter_provider:
            views:
              - selector:
                  instrument_name: requests
                  instrument_type: counter
                stream:
                  aggregation:
                    default: {}
        YAML
          require 'dash0-opentelemetry'
          exporter = ::OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
          ::OpenTelemetry.meter_provider.add_metric_reader(exporter)
          ::OpenTelemetry.meter_provider.meter('test').create_counter('requests').add(3)
          exporter.pull

          { values: exporter.metric_snapshots.flat_map { |m| m.data_points.map(&:value) } }
        end

        refute result[:error], result[:error]
        assert_equal [3], result[:values]
      end

      def test_create_keeps_a_meter_provider_built_by_opentelemetry_config
        result = run_in_subprocess do
          require 'dash0/opentelemetry'
          Dash0::OpenTelemetry::SdkConfiguration.require_sdk_gems
          require 'opentelemetry-config'

          upstream_provider = ::OpenTelemetry::SDK::Metrics::MeterProvider.new
          ::OpenTelemetry::Config.define_singleton_method(:create) do |_model|
            ::OpenTelemetry::Config::RubySDK.new(meter_provider: upstream_provider)
          end
          Dash0::OpenTelemetry::DeclarativeConfig::Metrics.define_singleton_method(:build_meter_provider) do |*|
            raise 'must not build a meter provider when opentelemetry-config already did'
          end

          model = ::OpenTelemetry::Config::Model::OpenTelemetryConfiguration.from_hash(
            'file_format' => '1.0', 'meter_provider' => { 'readers' => [] }
          )
          sdk = Dash0::OpenTelemetry::DeclarativeConfig.create(model)
          { same: sdk.meter_provider.equal?(upstream_provider) }
        end

        refute result[:error], result[:error]
        assert result[:same]
      end

      def test_headers_to_hash
        headers = Struct.new(:name, :value)
        cfg = Struct.new(:headers, :headers_list)

        assert_equal({ 'a' => '1' }, DeclarativeConfig.headers_to_hash(cfg.new([headers.new('a', '1')], 'b=2')))
        assert_equal({ 'b' => '2', 'c' => '3=4' }, DeclarativeConfig.headers_to_hash(cfg.new(nil, 'b=2, c=3=4')))
        assert_empty DeclarativeConfig.headers_to_hash(cfg.new(nil, nil))
      end
    end
  end
end
