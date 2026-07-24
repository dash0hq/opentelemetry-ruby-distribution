# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require_relative 'integration_helper'

module Dash0
  module OpenTelemetry
    class MinimumVersionTest < Minitest::Test
      include IntegrationHelper

      # On an unsupported Ruby the entry point must stand down cleanly: no crash,
      # no telemetry, and the rest of the distribution never loaded.
      def test_stands_down_on_unsupported_ruby
        with_collector do |collector|
          stdout, stderr, status = run_distro_app(
            'minimum_version_app.rb',
            env: { 'DASH0_OTEL_COLLECTOR_BASE_URL' => collector.base_url },
            preload: false
          )

          assert_predicate status, :success?, "app exited non-zero:\n#{stderr}"
          assert_includes stdout, 'BOOT_DEFINED=no', 'distribution should not have loaded on an unsupported Ruby'
          assert_match(/not supported/, stderr)

          # Give any (unexpected) export a chance to arrive, then assert none did.
          sleep 0.5

          assert_empty collector.span_names
          assert_empty collector.metric_names
          assert_empty collector.log_bodies
        end
      end
    end
  end
end
