# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require_relative 'integration_helper'

module Dash0
  module OpenTelemetry
    class AutoInstrumentationTest < Minitest::Test
      include IntegrationHelper

      # Proves the TracePoint sweep instruments a library (`net/http`) that the
      # app loads *after* the distribution was preloaded.
      def test_instruments_net_http_loaded_after_startup
        with_collector do |collector|
          _stdout, stderr, status = run_distro_app(
            'net_http_app.rb',
            env: {
              'DASH0_OTEL_COLLECTOR_BASE_URL' => collector.base_url,
              'TARGET_URL' => "#{collector.base_url}/ping"
            }
          )

          assert_predicate status, :success?, "app exited non-zero:\n#{stderr}"

          wait_until { collector.span_scope_names.include?('OpenTelemetry::Instrumentation::Net::HTTP') }

          assert_includes collector.span_scope_names, 'OpenTelemetry::Instrumentation::Net::HTTP'
        end
      end
    end
  end
end
