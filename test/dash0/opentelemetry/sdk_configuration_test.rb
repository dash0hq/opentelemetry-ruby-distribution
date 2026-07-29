# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    class SdkConfigurationTest < Minitest::Test
      include TestHelpers

      def test_full_boot_configures_sdk_and_exports_a_span
        result = run_in_subprocess('DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318') do
          require 'dash0-opentelemetry'

          tracer_provider = ::OpenTelemetry.tracer_provider
          resource_attributes = tracer_provider.instance_variable_get(:@resource).instance_variable_get(:@attributes)

          # Attach an in-memory exporter to prove the trace pipeline is wired up.
          exporter = ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
          tracer_provider.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
          tracer_provider.tracer('test-tracer').in_span('test-span') { |span| span.set_attribute('k', 'v') }

          {
            booted: Dash0::OpenTelemetry::Boot.booted?,
            tracer_provider_class: tracer_provider.class.name,
            distro_name: resource_attributes['telemetry.distro.name'],
            distro_version: resource_attributes['telemetry.distro.version'],
            endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil),
            protocol: ENV.fetch('OTEL_EXPORTER_OTLP_PROTOCOL', nil),
            span_names: exporter.finished_spans.map(&:name)
          }
        end

        refute result[:error], result[:error]
        assert result[:booted]
        assert_equal 'OpenTelemetry::SDK::Trace::TracerProvider', result[:tracer_provider_class]
        assert_equal 'dash0-ruby', result[:distro_name]
        assert_equal Dash0::OpenTelemetry::VERSION, result[:distro_version]
        assert_equal 'http://localhost:4318', result[:endpoint]
        assert_equal 'http/protobuf', result[:protocol]
        assert_includes result[:span_names], 'test-span'
      end

      def test_full_boot_configures_metrics_and_logs
        result = run_in_subprocess('DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318') do
          require 'dash0-opentelemetry'

          # Metrics
          metric_exporter = ::OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
          ::OpenTelemetry.meter_provider.add_metric_reader(metric_exporter)
          ::OpenTelemetry.meter_provider.meter('test-meter').create_counter('test.counter').add(2)
          metric_exporter.pull

          # Logs
          log_exporter = ::OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new
          ::OpenTelemetry.logger_provider.add_log_record_processor(
            ::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(log_exporter)
          )
          ::OpenTelemetry.logger_provider.logger(name: 'test-logger').on_emit(severity_text: 'INFO', body: 'hello')

          {
            meter_provider_class: ::OpenTelemetry.meter_provider.class.name,
            logger_provider_class: ::OpenTelemetry.logger_provider.class.name,
            metric_names: metric_exporter.metric_snapshots.map(&:name),
            log_bodies: log_exporter.emitted_log_records.map(&:body)
          }
        end

        refute result[:error], result[:error]
        assert_equal 'OpenTelemetry::SDK::Metrics::MeterProvider', result[:meter_provider_class]
        assert_equal 'OpenTelemetry::SDK::Logs::LoggerProvider', result[:logger_provider_class]
        assert_includes result[:metric_names], 'test.counter'
        assert_includes result[:log_bodies], 'hello'
      end

      def test_debug_print_spans_adds_console_processor_without_disabling_otlp
        result = run_in_subprocess(
          'DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318',
          'DASH0_DEBUG_PRINT_SPANS' => 'true'
        ) do
          require 'dash0-opentelemetry'
          processors = ::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)
          { processor_classes: processors.map { |p| p.class.name } }
        end

        refute result[:error], result[:error]
        # OTLP export (BatchSpanProcessor) must remain, with the console printer added alongside.
        assert_includes result[:processor_classes], 'OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor'
        assert_includes result[:processor_classes], 'OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor'
      end

      def test_wires_bundled_otel_gems_onto_the_load_path
        # Reproduces the injector's Bundler-less contract: the OpenTelemetry gems
        # live only under OTEL_RUBY_ADDITIONAL_GEM_PATH and must be put on the load
        # path — but application gems in the same mount must NOT be, to avoid
        # shadowing the app's own dependencies.
        result = run_in_subprocess do
          require 'tmpdir'
          require 'fileutils'
          require 'dash0/opentelemetry'

          mount = Dir.mktmpdir
          %w[
            opentelemetry-sdk-1.11.0
            google-protobuf-4.35.1
            googleapis-common-protos-types-1.0.0
            logger-1.7.0
            some-application-gem-2.0.0
          ].each { |g| FileUtils.mkdir_p(File.join(mount, 'gems', g, 'lib')) }

          ENV['OTEL_RUBY_ADDITIONAL_GEM_PATH'] = mount
          before = $LOAD_PATH.dup
          Dash0::OpenTelemetry::SdkConfiguration.wire_additional_gem_path
          added = ($LOAD_PATH - before).map { |path| File.basename(File.dirname(path)) }

          { added: added }
        end

        refute result[:error], result[:error]
        assert_includes result[:added], 'opentelemetry-sdk-1.11.0'
        assert_includes result[:added], 'google-protobuf-4.35.1'
        assert_includes result[:added], 'googleapis-common-protos-types-1.0.0'
        assert_includes result[:added], 'logger-1.7.0'
        refute_includes result[:added], 'some-application-gem-2.0.0'
      end

      def test_wire_additional_gem_path_is_a_no_op_without_the_env_var
        result = run_in_subprocess('OTEL_RUBY_ADDITIONAL_GEM_PATH' => nil) do
          require 'dash0/opentelemetry'
          before = $LOAD_PATH.dup
          Dash0::OpenTelemetry::SdkConfiguration.wire_additional_gem_path
          { changed: $LOAD_PATH != before }
        end

        refute result[:error], result[:error]
        refute result[:changed]
      end

      def test_wire_additional_gem_path_is_a_no_op_when_the_mount_does_not_exist
        result = run_in_subprocess('OTEL_RUBY_ADDITIONAL_GEM_PATH' => '/nonexistent/mount/path') do
          require 'dash0/opentelemetry'
          before = $LOAD_PATH.dup
          Dash0::OpenTelemetry::SdkConfiguration.wire_additional_gem_path
          { changed: $LOAD_PATH != before }
        end

        refute result[:error], result[:error]
        refute result[:changed]
      end

      def test_does_not_override_an_explicit_endpoint
        result = run_in_subprocess(
          'DASH0_OTEL_COLLECTOR_BASE_URL' => 'http://localhost:4318',
          'OTEL_EXPORTER_OTLP_ENDPOINT' => 'http://custom:4318'
        ) do
          require 'dash0-opentelemetry'
          { endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil) }
        end

        refute result[:error], result[:error]
        assert_equal 'http://custom:4318', result[:endpoint]
      end
    end
  end
end
