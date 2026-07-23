# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    class LifecycleTest < Minitest::Test
      include TestHelpers

      # --- Pure env-gate predicates (in-process; no SDK loaded) ---

      def test_flush_on_signals_gate
        with_env('DASH0_FLUSH_ON_SIGTERM_SIGINT' => 'true') { assert Lifecycle.send(:flush_on_signals?) }
        with_env('DASH0_FLUSH_ON_SIGTERM_SIGINT' => nil) { refute Lifecycle.send(:flush_on_signals?) }
      end

      def test_flush_on_exit_is_on_by_default_and_opt_out
        with_env('DASH0_FLUSH_ON_EXIT' => nil) { assert Lifecycle.send(:flush_on_exit?) }
        with_env('DASH0_FLUSH_ON_EXIT' => 'false') { refute Lifecycle.send(:flush_on_exit?) }
      end

      def test_bootstrap_span_name
        with_env('DASH0_BOOTSTRAP_SPAN' => 'startup') { assert_equal 'startup', Lifecycle.send(:bootstrap_span_name) }
        with_env('DASH0_BOOTSTRAP_SPAN' => '  ') { assert_nil Lifecycle.send(:bootstrap_span_name) }
        with_env('DASH0_BOOTSTRAP_SPAN' => nil) { assert_nil Lifecycle.send(:bootstrap_span_name) }
      end

      # --- Behavior in an isolated process (SDK configured) ---

      def test_bootstrap_span_is_an_internal_span
        result = run_in_subprocess do
          require 'opentelemetry-sdk'
          require 'dash0/opentelemetry'

          exporter = ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
          provider = ::OpenTelemetry::SDK::Trace::TracerProvider.new
          provider.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
          ::OpenTelemetry.tracer_provider = provider

          Dash0::OpenTelemetry::Lifecycle.send(:create_bootstrap_span, 'my-bootstrap')

          {
            names: exporter.finished_spans.map(&:name),
            kinds: exporter.finished_spans.map { |span| span.kind.to_s }
          }
        end

        refute result[:error], result[:error]
        assert_includes result[:names], 'my-bootstrap'
        assert_includes result[:kinds], 'internal'
      end

      def test_shutdown_flushes_and_is_idempotent
        result = run_in_subprocess do
          require 'opentelemetry-sdk'
          require 'dash0/opentelemetry'

          # A capturing exporter whose shutdown does NOT clear its buffer (unlike
          # InMemorySpanExporter), so we can assert what was flushed on shutdown.
          sink = []
          exporter = Class.new do
            def initialize(sink) = (@sink = sink)
            def export(spans, **) = @sink.concat(spans.map(&:name)) && ::OpenTelemetry::SDK::Trace::Export::SUCCESS
            def force_flush(**) = ::OpenTelemetry::SDK::Trace::Export::SUCCESS
            def shutdown(**) = ::OpenTelemetry::SDK::Trace::Export::SUCCESS
          end.new(sink)

          provider = ::OpenTelemetry::SDK::Trace::TracerProvider.new
          provider.add_span_processor(::OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter))
          ::OpenTelemetry.tracer_provider = provider
          provider.tracer('t').in_span('pending') { nil }

          Dash0::OpenTelemetry::Lifecycle.shutdown
          flagged = Dash0::OpenTelemetry::Lifecycle.shutdown?
          Dash0::OpenTelemetry::Lifecycle.shutdown # second call must be a safe no-op

          { shutdown_flag: flagged, exported: sink }
        end

        refute result[:error], result[:error]
        assert result[:shutdown_flag]
        # Flushed exactly once: the idempotency guard prevents a second shutdown.
        assert_equal ['pending'], result[:exported]
      end

      def test_signal_handlers_installed_when_opted_in
        result = run_in_subprocess('DASH0_FLUSH_ON_SIGTERM_SIGINT' => 'true') do
          require 'opentelemetry-sdk'
          require 'dash0/opentelemetry'
          Dash0::OpenTelemetry::Lifecycle.install
          {
            term_is_proc: Signal.trap('TERM', 'DEFAULT').is_a?(Proc),
            int_is_proc: Signal.trap('INT', 'DEFAULT').is_a?(Proc)
          }
        end

        refute result[:error], result[:error]
        assert result[:term_is_proc], 'expected a SIGTERM handler to be installed'
        assert result[:int_is_proc], 'expected a SIGINT handler to be installed'
      end

      def test_signal_handlers_not_installed_when_not_opted_in
        result = run_in_subprocess('DASH0_FLUSH_ON_SIGTERM_SIGINT' => nil) do
          require 'opentelemetry-sdk'
          require 'dash0/opentelemetry'
          Dash0::OpenTelemetry::Lifecycle.install
          { term_is_proc: Signal.trap('TERM', 'DEFAULT').is_a?(Proc) }
        end

        refute result[:error], result[:error]
        refute result[:term_is_proc], 'expected no SIGTERM handler when the opt-in is unset'
      end
    end
  end
end
