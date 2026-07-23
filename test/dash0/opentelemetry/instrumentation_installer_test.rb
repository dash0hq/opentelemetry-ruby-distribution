# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    class InstrumentationInstallerTest < Minitest::Test
      include TestHelpers

      # The core reason this distribution ports the TracePoint sweep instead of
      # calling `use_all` at configure time: when the distribution is preloaded
      # before the app's libraries, an instrumentation whose target loads *later*
      # must still be installed. This proves the deferred install works — and,
      # by extension, that a configure-time `use_all` (which only installs
      # already-present targets) would have missed it.
      def test_installs_instrumentation_whose_library_loads_after_startup
        result = run_in_subprocess do
          require 'dash0/opentelemetry'
          require 'opentelemetry-instrumentation-all'

          # A fake instrumentation that is only "present" once a sentinel class
          # exists. It is absent during the initial sweep.
          Object.const_set(:Dash0LateLoadInstrumentation, Class.new(::OpenTelemetry::Instrumentation::Base) do
            present { defined?(::Dash0LateLoadSentinel) ? true : false }
            install { |_config| true }
          end)

          Dash0::OpenTelemetry::InstrumentationInstaller.start([])

          installed_before = Dash0LateLoadInstrumentation.instance.installed?
          trace_point_enabled = Dash0::OpenTelemetry::InstrumentationInstaller.trace_point&.enabled?

          # Defining a class fires TracePoint(:end), which re-runs the sweep.
          eval 'class ::Dash0LateLoadSentinel; end', TOPLEVEL_BINDING, __FILE__, __LINE__

          {
            installed_before: installed_before,
            trace_point_enabled: trace_point_enabled,
            installed_after: Dash0LateLoadInstrumentation.instance.installed?
          }
        end

        refute result[:error], result[:error]
        refute result[:installed_before], 'must not be installed before its library is present'
        assert result[:trace_point_enabled], 'TracePoint should remain enabled while targets are absent'
        assert result[:installed_after], 'must be installed once its library loads (sweep runs on class definition)'
      end

      def test_enabled_instrumentation_names_resolves_aliases
        result = run_in_subprocess('OTEL_RUBY_ENABLED_INSTRUMENTATIONS' => 'net_http') do
          require 'dash0/opentelemetry'
          require 'opentelemetry-instrumentation-all'
          { names: Dash0::OpenTelemetry::InstrumentationInstaller.enabled_instrumentation_names }
        end

        refute result[:error], result[:error]
        assert_includes result[:names], 'OpenTelemetry::Instrumentation::Net::HTTP'
      end

      def test_enabled_instrumentation_names_empty_when_unset
        result = run_in_subprocess('OTEL_RUBY_ENABLED_INSTRUMENTATIONS' => nil) do
          require 'dash0/opentelemetry'
          require 'opentelemetry-instrumentation-all'
          { names: Dash0::OpenTelemetry::InstrumentationInstaller.enabled_instrumentation_names }
        end

        refute result[:error], result[:error]
        assert_empty result[:names]
      end
    end
  end
end
