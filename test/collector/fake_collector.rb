# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'webrick'
require 'zlib'

# The OTLP exporter gems ship compiled protobuf classes, so the mock collector
# can decode captured payloads without protoc or a proto submodule. Require only
# the generated `*_pb` files (google-protobuf) — NOT the exporter/SDK — so this
# test process never loads `opentelemetry-sdk`; otherwise forked unit-test
# subprocesses would inherit it and trip the double-instrumentation guard.
require 'opentelemetry/proto/collector/trace/v1/trace_service_pb'
require 'opentelemetry/proto/collector/metrics/v1/metrics_service_pb'
require 'opentelemetry/proto/collector/logs/v1/logs_service_pb'

# A minimal OTLP/HTTP collector for integration tests. It listens on an ephemeral
# loopback port, decodes the OTLP/protobuf requests the distribution exports
# (gunzipping gzip-compressed bodies), and stores them for assertions. Any other
# path returns 200 so instrumented client calls made by the app under test (e.g.
# a Net::HTTP request pointed at this server) succeed.
class FakeCollector
  Proto = Opentelemetry::Proto

  SIGNALS = {
    '/v1/traces' => [
      :traces,
      Proto::Collector::Trace::V1::ExportTraceServiceRequest,
      Proto::Collector::Trace::V1::ExportTraceServiceResponse
    ],
    '/v1/metrics' => [
      :metrics,
      Proto::Collector::Metrics::V1::ExportMetricsServiceRequest,
      Proto::Collector::Metrics::V1::ExportMetricsServiceResponse
    ],
    '/v1/logs' => [
      :logs,
      Proto::Collector::Logs::V1::ExportLogsServiceRequest,
      Proto::Collector::Logs::V1::ExportLogsServiceResponse
    ]
  }.freeze

  def initialize
    @mutex = Mutex.new
    @requests = { traces: [], metrics: [], logs: [] }
    @server = WEBrick::HTTPServer.new(
      BindAddress: '127.0.0.1',
      Port: 0,
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
    install_handlers
  end

  def start
    @thread = Thread.new { @server.start }
    self
  end

  def stop
    @server.shutdown
    @thread&.join
  end

  def port
    @server.listeners.first.addr[1]
  end

  def base_url
    "http://127.0.0.1:#{port}"
  end

  # --- Decoded query helpers ---

  def spans
    resource_spans.flat_map { |rs| rs.scope_spans.flat_map(&:spans) }
  end

  def span_names
    spans.map(&:name)
  end

  # Instrumentation scope names across all captured spans, e.g.
  # "OpenTelemetry::Instrumentation::Net::HTTP".
  def span_scope_names
    resource_spans.flat_map { |rs| rs.scope_spans.map { |ss| ss.scope&.name } }.compact
  end

  def metric_names
    request(:metrics)
      .flat_map(&:resource_metrics)
      .flat_map(&:scope_metrics)
      .flat_map(&:metrics)
      .map(&:name)
  end

  def log_bodies
    request(:logs)
      .flat_map(&:resource_logs)
      .flat_map(&:scope_logs)
      .flat_map(&:log_records)
      .map { |lr| any_value_to_ruby(lr.body) }
  end

  # Resource attributes as a Ruby hash, taken from the first resource seen on any
  # signal (all signals share the same distribution resource).
  def resource_attributes
    resource =
      resource_spans.map(&:resource).first ||
      request(:metrics).flat_map(&:resource_metrics).map(&:resource).first ||
      request(:logs).flat_map(&:resource_logs).map(&:resource).first
    return {} unless resource

    resource.attributes.to_h { |kv| [kv.key, any_value_to_ruby(kv.value)] }
  end

  private

  def resource_spans
    request(:traces).flat_map(&:resource_spans)
  end

  def request(signal)
    @mutex.synchronize { @requests.fetch(signal).dup }
  end

  def install_handlers
    SIGNALS.each do |path, (signal, request_class, response_class)|
      @server.mount_proc(path) do |http_request, http_response|
        store(signal, request_class.decode(payload_of(http_request)))
        http_response.status = 200
        http_response['Content-Type'] = 'application/x-protobuf'
        http_response.body = response_class.new.to_proto
      end
    end

    # Catch-all so instrumented client requests from the app under test succeed.
    @server.mount_proc('/') do |_request, response|
      response.status = 200
      response.body = 'ok'
    end
  end

  def payload_of(http_request)
    body = http_request.body.to_s
    http_request['content-encoding'].to_s.include?('gzip') ? Zlib.gunzip(body) : body
  end

  def store(signal, decoded)
    @mutex.synchronize { @requests.fetch(signal) << decoded }
  end

  def any_value_to_ruby(value)
    return nil if value.nil?

    case value.value
    when :string_value then value.string_value
    when :bool_value then value.bool_value
    when :int_value then value.int_value
    when :double_value then value.double_value
    else value.to_s
    end
  end
end
