# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    class PropagationTest < Minitest::Test
      include TestHelpers

      BOOT_ENV = { 'DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318' }.freeze

      TC_TRACE_ID = '4bf92f3577b34da6a3ce929d0e0e4736'
      TC_SPAN_ID = '00f067aa0ba902b7'
      TRACEPARENT = "00-#{TC_TRACE_ID}-#{TC_SPAN_ID}-01".freeze

      XRAY_TRACE_ID = '5759e988bd862e3fe1be46a994272793'
      XRAY_SPAN_ID = '53995c3f42cd8ad8'
      XRAY_ROOT = '1-5759e988-bd862e3fe1be46a994272793'

      def test_defaults_to_tracecontext_baggage_then_xray
        result = run_in_subprocess(BOOT_ENV) do
          require 'dash0-opentelemetry'
          { propagators: propagator_classes }
        end

        refute result[:error], result[:error]
        assert_equal [
          'OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator',
          'OpenTelemetry::Baggage::Propagation::TextMapPropagator',
          'OpenTelemetry::Propagator::XRay::TextMapPropagator'
        ], result[:propagators]
      end

      def test_default_does_not_leak_into_child_processes
        result = run_in_subprocess(BOOT_ENV) do
          require 'dash0-opentelemetry'
          child = IO.popen(['ruby', '-e', 'print ENV.fetch("OTEL_PROPAGATORS", "unset")'], &:read)
          { env: ENV.fetch('OTEL_PROPAGATORS', nil), child: child }
        end

        refute result[:error], result[:error]
        assert_nil result[:env]
        assert_equal 'unset', result[:child]
      end

      def test_xray_wins_when_both_headers_are_present
        result = extract_after_boot(
          'traceparent' => TRACEPARENT,
          'X-Amzn-Trace-Id' => "Root=#{XRAY_ROOT};Parent=#{XRAY_SPAN_ID};Sampled=1"
        )

        refute result[:error], result[:error]
        assert_equal [XRAY_TRACE_ID, XRAY_SPAN_ID, true], result[:extracted]
      end

      def test_extracts_an_alb_rewritten_header_with_self_and_unknown_fields
        header = "Self=1-67891234-12456789abcdef012345678;Root=#{XRAY_ROOT};" \
                 "Parent=#{XRAY_SPAN_ID};Sampled=1;Lineage=a87bd80c:1|68fd508a:5"
        result = extract_after_boot('X-Amzn-Trace-Id' => header)

        refute result[:error], result[:error]
        assert_equal [XRAY_TRACE_ID, XRAY_SPAN_ID, true], result[:extracted]
      end

      def test_root_only_header_keeps_the_tracecontext_parent
        result = extract_after_boot(
          'traceparent' => TRACEPARENT,
          'X-Amzn-Trace-Id' => 'Root=1-67891233-abcdef012345678912345678'
        )

        refute result[:error], result[:error]
        assert_equal [TC_TRACE_ID, TC_SPAN_ID, true], result[:extracted]
      end

      def test_root_only_header_alone_extracts_no_parent
        result = extract_after_boot('X-Amzn-Trace-Id' => 'Root=1-67891233-abcdef012345678912345678')

        refute result[:error], result[:error]
        assert_nil result[:extracted]
      end

      def test_inject_writes_both_headers_for_the_same_span
        result = run_in_subprocess(BOOT_ENV) do
          require 'dash0-opentelemetry'
          carrier = {}
          ::OpenTelemetry.tracer_provider.tracer('test').in_span('outgoing') do |span|
            ::OpenTelemetry.propagation.inject(carrier)
            { carrier: carrier, trace_id: span.context.hex_trace_id, span_id: span.context.hex_span_id }
          end
        end

        refute result[:error], result[:error]
        trace_id = result[:trace_id]

        assert_equal "00-#{trace_id}-#{result[:span_id]}-01", result[:carrier]['traceparent']
        assert_equal "Root=1-#{trace_id[0..7]}-#{trace_id[8..]};Parent=#{result[:span_id]};Sampled=1",
                     result[:carrier]['X-Amzn-Trace-Id']
      end

      def test_baggage_round_trips_with_the_default
        result = run_in_subprocess(BOOT_ENV) do
          require 'dash0-opentelemetry'
          context = ::OpenTelemetry.propagation.extract({ 'baggage' => 'tenant=acme,region=eu' })
          carrier = {}
          ::OpenTelemetry.propagation.inject(carrier, context: context)
          { extracted: ::OpenTelemetry::Baggage.values(context: context), injected: carrier['baggage'] }
        end

        refute result[:error], result[:error]
        assert_equal({ 'tenant' => 'acme', 'region' => 'eu' }, result[:extracted])
        assert_equal 'tenant=acme,region=eu', result[:injected]
      end

      def test_baggage_survives_an_xray_header_with_lineage
        result = run_in_subprocess(BOOT_ENV) do
          require 'dash0-opentelemetry'
          context = ::OpenTelemetry.propagation.extract(
            {
              'baggage' => 'tenant=acme',
              'X-Amzn-Trace-Id' => "Root=#{XRAY_ROOT};Parent=#{XRAY_SPAN_ID};Sampled=1;Lineage=a87bd80c:1|68fd508a:5"
            }
          )
          span_context = ::OpenTelemetry::Trace.current_span(context).context
          { baggage: ::OpenTelemetry::Baggage.values(context: context), trace_id: span_context.hex_trace_id }
        end

        refute result[:error], result[:error]
        assert_equal({ 'tenant' => 'acme' }, result[:baggage])
        assert_equal XRAY_TRACE_ID, result[:trace_id]
      end

      def test_honors_an_explicit_otel_propagators
        result = run_in_subprocess(BOOT_ENV.merge('OTEL_PROPAGATORS' => 'tracecontext,baggage')) do
          require 'dash0-opentelemetry'
          { env: ENV.fetch('OTEL_PROPAGATORS', nil), propagators: propagator_classes }
        end

        refute result[:error], result[:error]
        assert_equal 'tracecontext,baggage', result[:env]
        assert_equal [
          'OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator',
          'OpenTelemetry::Baggage::Propagation::TextMapPropagator'
        ], result[:propagators]
      end

      def test_xray_alone_is_selectable
        result = run_in_subprocess(BOOT_ENV.merge('OTEL_PROPAGATORS' => 'xray')) do
          require 'dash0-opentelemetry'
          { propagators: propagator_classes }
        end

        refute result[:error], result[:error]
        assert_equal ['OpenTelemetry::Propagator::XRay::TextMapPropagator'], result[:propagators]
      end

      def test_config_file_can_select_xray_and_gets_no_env_default
        result = run_in_subprocess('OTEL_CONFIG_FILE' => write_config_file(<<~YAML)) do
          file_format: "1.0"
          propagator:
            composite:
              - tracecontext:
              - xray:
        YAML
          require 'dash0-opentelemetry'
          { env: ENV.fetch('OTEL_PROPAGATORS', nil), propagators: propagator_classes }
        end

        refute result[:error], result[:error]
        assert_nil result[:env]
        assert_equal [
          'OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator',
          'OpenTelemetry::Propagator::XRay::TextMapPropagator'
        ], result[:propagators]
      end

      private

      def propagator_classes
        propagation = ::OpenTelemetry.propagation
        # A single configured propagator is installed as-is, not wrapped in a composite.
        propagators = propagation.instance_variable_get(:@propagators) || [propagation]
        propagators.map { |p| p.class.name }
      end

      # Boots the distribution and extracts from +carrier+ with the global
      # propagator; returns [trace_id, span_id, sampled] or nil when no valid
      # parent was extracted.
      def extract_after_boot(carrier)
        run_in_subprocess(BOOT_ENV) do
          require 'dash0-opentelemetry'
          context = ::OpenTelemetry.propagation.extract(carrier)
          span_context = ::OpenTelemetry::Trace.current_span(context).context
          next { extracted: nil } unless span_context.valid?

          { extracted: [span_context.hex_trace_id, span_context.hex_span_id, span_context.trace_flags.sampled?] }
        end
      end
    end
  end
end
