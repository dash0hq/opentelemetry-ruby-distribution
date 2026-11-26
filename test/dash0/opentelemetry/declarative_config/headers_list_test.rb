# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'yaml'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    module DeclarativeConfig
      class HeadersListTest < Minitest::Test
        include TestHelpers

        SIGNALS = %i[traces metrics logs].freeze

        def test_headers_list_is_percent_decoded_for_every_signal
          headers = boot_exporter_headers('headers_list' => 'Authorization=Bearer%20tok,Dash0%2DDataset=ds')

          assert_every_signal({ 'Authorization' => 'Bearer tok', 'Dash0-Dataset' => 'ds' }, headers)
        end

        def test_headers_struct_values_stay_as_written
          headers = boot_exporter_headers('headers' => [{ 'name' => 'Authorization', 'value' => 'Bearer%20tok' }])

          assert_every_signal({ 'Authorization' => 'Bearer%20tok' }, headers)
        end

        def test_invalid_percent_encoding_stays_as_written
          headers = boot_exporter_headers('headers_list' => 'Authorization=Bearer%zz')

          assert_every_signal({ 'Authorization' => 'Bearer%zz' }, headers)
        end

        def test_install_skips_an_opentelemetry_config_that_decodes
          result = run_in_subprocess do
            require 'dash0/opentelemetry'
            Dash0::OpenTelemetry::SdkConfiguration.require_sdk_gems
            require 'opentelemetry-config'
            trace = ::OpenTelemetry::Config.const_get(:Trace, false)
            trace.define_singleton_method(:headers_to_hash) { |_cfg| { 'k' => 'a b' } }

            HeadersList.install
            trace.singleton_class.ancestors.include?(HeadersList::TracePatch)
          end

          refute result.is_a?(Hash) && result[:error], result.is_a?(Hash) && result[:error]
          refute result
        end

        private

        def assert_every_signal(expected, headers)
          assert_equal(SIGNALS.to_h { |signal| [signal, expected] }, headers)
        end

        # Boots from a configuration file whose OTLP exporters all carry
        # +header_settings+, and returns the headers each exporter sends.
        def boot_exporter_headers(header_settings)
          result = run_in_subprocess('OTEL_CONFIG_FILE' => write_config_file(config_yaml(header_settings))) do
            require 'dash0-opentelemetry'
            headers = lambda do |holder|
              holder.instance_variable_get(:@exporter).instance_variable_get(:@headers).except('User-Agent')
            end
            {
              traces: headers.call(::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors).first),
              metrics: headers.call(::OpenTelemetry.meter_provider.instance_variable_get(:@metric_readers).first),
              logs: headers.call(::OpenTelemetry.logger_provider.instance_variable_get(:@log_record_processors).first)
            }
          end

          refute result[:error], result[:error]
          result
        end

        def config_yaml(header_settings)
          # A new hash per signal, so YAML.dump writes no aliases.
          exporter = lambda do
            { 'otlp_http' => { 'endpoint' => 'http://localhost:4318' }.merge(Marshal.load(Marshal.dump(header_settings))) }
          end
          YAML.dump(
            'file_format' => '1.0',
            'tracer_provider' => { 'processors' => [{ 'batch' => { 'exporter' => exporter.call } }] },
            'meter_provider' => { 'readers' => [{ 'periodic' => { 'exporter' => exporter.call } }] },
            'logger_provider' => { 'processors' => [{ 'batch' => { 'exporter' => exporter.call } }] }
          )
        end
      end
    end
  end
end
