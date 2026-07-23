# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  class OpenTelemetryTest < Minitest::Test
    def test_version_is_defined
      refute_nil Dash0::OpenTelemetry::VERSION
      assert_match(/\A\d+\.\d+\.\d+/, Dash0::OpenTelemetry::VERSION)
    end

    def test_boot_is_a_safe_no_op_for_now
      assert_nil Dash0::OpenTelemetry.boot!
    end

    def test_requiring_the_entry_point_does_not_raise
      # The requirable entry point boots the distribution as a side effect;
      # requiring it must never raise.
      require 'dash0-opentelemetry'
    end
  end
end
