# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    module Resource
      class DistributionTest < Minitest::Test
        include TestHelpers

        def test_detects_distro_name_and_version
          result = run_in_subprocess do
            require 'opentelemetry-sdk'
            require 'dash0/opentelemetry'
            resource = Dash0::OpenTelemetry::Resource::Distribution.detect
            resource.instance_variable_get(:@attributes)
          end

          refute result[:error], result[:error]
          assert_equal 'dash0-ruby', result['telemetry.distro.name']
          assert_equal Dash0::OpenTelemetry::VERSION, result['telemetry.distro.version']
        end
      end
    end
  end
end
