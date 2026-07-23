# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  class OpenTelemetryTest < Minitest::Test
    include TestHelpers

    def test_version_is_defined
      refute_nil Dash0::OpenTelemetry::VERSION
      assert_match(/\A\d+\.\d+\.\d+/, Dash0::OpenTelemetry::VERSION)
    end

    def test_requiring_the_module_has_no_side_effects
      # Requiring the namespace must not boot the distribution on its own.
      refute_predicate Dash0::OpenTelemetry::Boot, :booted?
    end

    def test_requiring_the_entry_point_does_not_raise
      # With no collector base URL set, requiring the entry point boots and then
      # cleanly stands down. It must never raise.
      output = run_in_subprocess('DASH0_OTEL_COLLECTOR_BASE_URL' => nil) do
        require 'dash0-opentelemetry'
        { booted: Dash0::OpenTelemetry::Boot.booted? }
      end

      refute output[:error], output[:error]
      refute output[:booted]
    end
  end
end
