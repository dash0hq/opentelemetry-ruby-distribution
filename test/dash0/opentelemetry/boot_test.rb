# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    class BootTest < Minitest::Test
      include TestHelpers

      def test_disabled_gate
        with_env('DASH0_DISABLE' => 'true') { assert Boot.send(:disabled?) }
        with_env('DASH0_DISABLE' => 'false') { refute Boot.send(:disabled?) }
        with_env('DASH0_DISABLE' => nil) { refute Boot.send(:disabled?) }
      end

      def test_collector_base_url_gate
        with_env('DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://collector:4318') do
          assert_equal 'http://collector:4318', Boot.send(:collector_base_url)
        end
        with_env('DASH0_OTEL_COLLECTOR_BASE_URL' => '  http://c:4318 ') do
          assert_equal 'http://c:4318', Boot.send(:collector_base_url)
        end
        with_env('DASH0_OTEL_COLLECTOR_BASE_URL' => nil) do
          assert_nil Boot.send(:collector_base_url)
        end
        with_env('DASH0_OTEL_COLLECTOR_BASE_URL' => '   ') do
          assert_nil Boot.send(:collector_base_url)
        end
      end

      def test_config_file_gate_uses_otel_config_file_when_set
        default_path = write_config_file('file_format: "1.0"')

        with_env('OTEL_CONFIG_FILE' => ' /etc/otel.yaml ') do
          assert_equal '/etc/otel.yaml', Boot.send(:config_file_path, default_path)
        end
      end

      def test_config_file_gate_falls_back_to_the_default_file_when_it_exists
        default_path = write_config_file('file_format: "1.0"')

        with_env('OTEL_CONFIG_FILE' => nil) { assert_equal default_path, Boot.send(:config_file_path, default_path) }
        with_env('OTEL_CONFIG_FILE' => '  ') { assert_equal default_path, Boot.send(:config_file_path, default_path) }
      end

      def test_config_file_gate_is_nil_without_otel_config_file_or_default_file
        with_env('OTEL_CONFIG_FILE' => nil) { assert_nil Boot.send(:config_file_path, '/nonexistent/otel.yaml') }
        with_env('OTEL_CONFIG_FILE' => '  ') { assert_nil Boot.send(:config_file_path, '/nonexistent/otel.yaml') }
      end

      def test_boot_configures_from_the_default_file_when_otel_config_file_is_unset
        default_path = write_config_file('file_format: "1.0"')
        result = run_in_subprocess('DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318') do
          ENV.delete('OTEL_CONFIG_FILE')
          require 'stringio'
          require 'dash0/opentelemetry'
          boot = Dash0::OpenTelemetry::Boot
          boot.send(:remove_const, :DEFAULT_CONFIG_FILE)
          boot.const_set(:DEFAULT_CONFIG_FILE, default_path)
          configured = []
          boot.define_singleton_method(:configure) { |url| configured << [:env, url] }
          boot.define_singleton_method(:configure_from_file) { |path| configured << [:file, path] }

          $stderr = StringIO.new
          Dash0::OpenTelemetry.boot!
          { configured: configured, stderr: $stderr.string }
        end

        refute result[:error], result[:error]
        assert_equal [[:file, default_path]], result[:configured]
        assert_includes result[:stderr], "#{default_path} takes precedence over DASH0_OTEL_COLLECTOR_BASE_URL"
      end

      def test_config_file_takes_precedence_over_collector_base_url
        result = run_in_subprocess(
          'OTEL_CONFIG_FILE' => '/nonexistent/otel.yaml',
          'DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318'
        ) do
          require 'stringio'
          require 'dash0/opentelemetry'
          configured = []
          Dash0::OpenTelemetry::Boot.define_singleton_method(:configure) { |url| configured << [:env, url] }
          Dash0::OpenTelemetry::Boot.define_singleton_method(:configure_from_file) { |path| configured << [:file, path] }

          $stderr = StringIO.new
          Dash0::OpenTelemetry.boot!
          { configured: configured, stderr: $stderr.string }
        end

        refute result[:error], result[:error]
        assert_equal [[:file, '/nonexistent/otel.yaml']], result[:configured]
        assert_includes result[:stderr], 'takes precedence over DASH0_OTEL_COLLECTOR_BASE_URL'
      end

      def test_sdk_loaded_detection
        assert Boot.send(:sdk_loaded?, ['/gems/opentelemetry-sdk-1.11.0/lib/opentelemetry/sdk.rb'])
        refute Boot.send(:sdk_loaded?, ['/gems/some-other-gem/lib/foo.rb'])
        refute Boot.send(:sdk_loaded?, [])
      end

      def test_disabled_boot_does_not_configure
        result = run_in_subprocess(
          'DASH0_DISABLE' => 'true',
          'DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318'
        ) do
          require 'dash0-opentelemetry'
          {
            booted: Dash0::OpenTelemetry::Boot.booted?,
            sdk_loaded: $LOADED_FEATURES.any? { |p| p.end_with?('lib/opentelemetry/sdk.rb') }
          }
        end

        refute result[:error], result[:error]
        refute result[:booted]
        refute result[:sdk_loaded], 'SDK must not be loaded when the distribution is disabled'
      end

      def test_double_instrumentation_guard_stands_down
        result = run_in_subprocess('DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318') do
          # Simulate an application that already set up OpenTelemetry itself.
          require 'opentelemetry-sdk'
          require 'dash0-opentelemetry'
          { booted: Dash0::OpenTelemetry::Boot.booted? }
        end

        refute result[:error], result[:error]
        refute result[:booted], 'distribution must stand down when OpenTelemetry SDK is already loaded'
      end

      # A LoadError raised while requiring the SDK gems (e.g. a missing/incomplete
      # injected bundle) must be caught, not propagated — otherwise it crashes the
      # host application. LoadError is a ScriptError, so `rescue StandardError`
      # alone would let it through.
      def test_boot_fails_open_when_sdk_gems_cannot_be_loaded
        result = run_in_subprocess('DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318') do
          require 'dash0/opentelemetry'
          Dash0::OpenTelemetry::SdkConfiguration.define_singleton_method(:require_sdk_gems) do
            raise LoadError, 'simulated missing gem bundle'
          end

          propagated = nil
          begin
            Dash0::OpenTelemetry.boot!
          rescue StandardError, ScriptError => e
            propagated = e.class.name
          end

          { propagated: propagated, booted: Dash0::OpenTelemetry::Boot.booted? }
        end

        refute result[:error], result[:error]
        assert_nil result[:propagated], "boot! must not propagate: got #{result[:propagated]}"
        refute result[:booted]
      end
    end
  end
end
