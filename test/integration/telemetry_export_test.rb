# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry/version'
require_relative 'integration_helper'

module Dash0
  module OpenTelemetry
    class TelemetryExportTest < Minitest::Test
      include IntegrationHelper

      def test_exports_all_three_signals_with_distro_resource
        with_collector do |collector|
          _stdout, stderr, status = run_distro_app(
            'telemetry_app.rb',
            env: { 'DASH0_OTEL_COLLECTOR_BASE_URL' => collector.base_url }
          )

          assert_predicate status, :success?, "app exited non-zero:\n#{stderr}"

          wait_until do
            collector.span_names.include?('work') &&
              collector.metric_names.include?('app.requests') &&
              !collector.log_bodies.empty?
          end

          assert_includes collector.span_names, 'work'
          assert_includes collector.metric_names, 'app.requests'
          assert_includes collector.log_bodies, 'hello from telemetry-app'

          attributes = collector.resource_attributes

          assert_equal 'dash0-ruby', attributes['telemetry.distro.name']
          assert_equal Dash0::OpenTelemetry::VERSION, attributes['telemetry.distro.version']
          # service.name falls back to the program entry point basename.
          assert_equal 'telemetry_app', attributes['service.name']
        end
      end
    end
  end
end
