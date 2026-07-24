# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require_relative 'integration_helper'

module Dash0
  module OpenTelemetry
    class RailsTest < Minitest::Test
      include IntegrationHelper

      # Default-stack smoke: a minimal Rails app dispatches an in-process request.
      # Rails is loaded after the distribution is preloaded, so this proves the
      # TracePoint sweep instruments the Rack/Rails stack during the real Rails
      # boot and that a server span is produced and exported.
      def test_instruments_a_rails_request
        with_collector do |collector|
          _stdout, stderr, status = run_distro_app(
            'rails_app.rb',
            env: { 'DASH0_OTEL_COLLECTOR_BASE_URL' => collector.base_url }
          )

          assert_predicate status, :success?, "app exited non-zero:\n#{stderr}"

          wait_until { collector.span_scope_names.include?('OpenTelemetry::Instrumentation::Rack') }

          assert_includes collector.span_scope_names, 'OpenTelemetry::Instrumentation::Rack'
          assert_includes collector.span_names, 'GET /hello'
        end
      end
    end
  end
end
