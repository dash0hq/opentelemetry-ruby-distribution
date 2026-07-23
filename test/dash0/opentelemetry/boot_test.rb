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
    end
  end
end
