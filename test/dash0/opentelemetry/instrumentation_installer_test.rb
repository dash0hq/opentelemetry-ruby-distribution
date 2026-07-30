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

      # The TracePoint fires while a library is still being required, so a target's
      # own constant exists before its version constant does. Upstream's
      # compatibility check reads that version and raises meanwhile, which must be
      # read as "not ready yet". The instrumentation has to install on a later sweep.
      def test_installs_instrumentation_whose_compatibility_check_raises_while_library_is_half_loaded
        result = run_in_subprocess do
          require 'dash0/opentelemetry'
          require 'opentelemetry-instrumentation-all'

          # Mirrors a half-loaded library: present from the start, but its version
          # is only readable once a sentinel exists, and reading it raises before
          # that, just as `ActiveSupport.version` does mid-require.
          Object.const_set(:Dash0HalfLoadedInstrumentation, Class.new(::OpenTelemetry::Instrumentation::Base) do
            present { true }
            compatible do
              raise NoMethodError, "undefined method 'version' for module Dash0HalfLoaded" unless
                defined?(::Dash0HalfLoadedVersionSentinel)

              true
            end
            install { |_config| true }
          end)

          Dash0::OpenTelemetry::InstrumentationInstaller.start([])

          installed_before = Dash0HalfLoadedInstrumentation.instance.installed?
          trace_point_enabled = Dash0::OpenTelemetry::InstrumentationInstaller.trace_point&.enabled?

          # The rest of the library finishes loading; defining a class also fires
          # TracePoint(:end), which re-runs the sweep.
          eval 'class ::Dash0HalfLoadedVersionSentinel; end', TOPLEVEL_BINDING, __FILE__, __LINE__

          {
            installed_before: installed_before,
            trace_point_enabled: trace_point_enabled,
            installed_after: Dash0HalfLoadedInstrumentation.instance.installed?
          }
        end

        refute result[:error], result[:error]
        refute result[:installed_before], 'must not be installed while its compatibility cannot be determined'
        assert result[:trace_point_enabled], 'TracePoint must stay enabled while an outcome can still change'
        assert result[:installed_after], 'must be installed once the library has finished loading'
      end

      # Quiet idempotence: an incompatible (or disabled) instrumentation is never
      # handed to the registry, on any sweep. That is what keeps the logs quiet —
      # the registry logs a warning for every instrumentation it is asked to
      # install but cannot, so re-submitting one on each of the ~per-request sweeps
      # would spam a warning per request forever. Pre-filtering before the registry
      # call is what lets the sweep stay stateless.
      def test_never_submits_incompatible_or_disabled_instrumentation_to_the_registry
        result = run_in_subprocess do
          require 'dash0/opentelemetry'
          require 'opentelemetry-instrumentation-all'

          Object.const_set(:Dash0IncompatibleInstrumentation, Class.new(::OpenTelemetry::Instrumentation::Base) do
            present { true }
            compatible { false }
            install { |_config| true }
          end)
          Object.const_set(:Dash0GoodInstrumentation, Class.new(::OpenTelemetry::Instrumentation::Base) do
            present { true }
            compatible { true }
            install { |_config| true }
          end)

          # Record every name handed to the registry for installation.
          registry = ::OpenTelemetry::Instrumentation.registry
          submitted = []
          original_install = registry.method(:install)
          registry.define_singleton_method(:install) do |names, *rest|
            submitted.concat(Array(names))
            original_install.call(names, *rest)
          end

          Dash0::OpenTelemetry::InstrumentationInstaller.start([])
          # Drive several more sweeps; each class definition fires TracePoint(:end).
          eval 'class ::Dash0SweepTrigger1; end', TOPLEVEL_BINDING, __FILE__, __LINE__
          eval 'class ::Dash0SweepTrigger2; end', TOPLEVEL_BINDING, __FILE__, __LINE__

          {
            good_installed: Dash0GoodInstrumentation.instance.installed?,
            incompatible_installed: Dash0IncompatibleInstrumentation.instance.installed?,
            incompatible_submitted: submitted.include?('Dash0IncompatibleInstrumentation'),
            good_submissions: submitted.count('Dash0GoodInstrumentation'),
            trace_point_armed: Dash0::OpenTelemetry::InstrumentationInstaller.trace_point&.enabled?
          }
        end

        refute result[:error], result[:error]
        assert result[:good_installed], 'a compatible instrumentation must install'
        refute result[:incompatible_installed], 'an incompatible instrumentation must not install'
        refute result[:incompatible_submitted],
               'an incompatible instrumentation must never be handed to the registry (would log a warning each sweep)'
        assert_equal 1, result[:good_submissions],
                     'a successful install must be submitted exactly once, then skipped via installed?'
        assert result[:trace_point_armed],
               'the TracePoint stays armed for the process lifetime (no disarm), and that is cheap'
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
