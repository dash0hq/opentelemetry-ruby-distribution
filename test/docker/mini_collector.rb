# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# OTLP/HTTP capture for the Docker injection smoke test. Records which OTLP paths
# received a body and, for traces, decodes the protobuf to emit the span
# instrumentation-scope names — so the harness can assert that an app was
# actually auto-instrumented (not just that some span was exported).
#
# Run with GEM_PATH pointed at the mounted bundle so the OTLP proto classes (and
# google-protobuf, for the container's libc) resolve. Responds with
# `Connection: close` so the exporter opens a fresh connection per request.

require 'socket'
require 'zlib'
require 'opentelemetry/proto/collector/trace/v1/trace_service_pb'

TRACE_REQUEST = Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest

def read_request(conn)
  request_line = conn.gets
  return nil unless request_line

  path = request_line.split(' ')[1]
  length = 0
  encoding = nil
  while (line = conn.gets) && line != "\r\n"
    key, value = line.split(':', 2)
    next unless key && value

    case key.strip.downcase
    when 'content-length' then length = value.to_i
    when 'content-encoding' then encoding = value.strip.downcase
    end
  end
  body = length.positive? ? conn.read(length).to_s : ''
  [path, encoding, body]
end

def emit_trace_scopes(encoding, body)
  payload = encoding == 'gzip' ? Zlib.gunzip(body) : body
  TRACE_REQUEST.decode(payload).resource_spans.each do |resource_spans|
    resource_spans.scope_spans.each do |scope_spans|
      name = scope_spans.scope&.name
      puts "COLLECTOR_SCOPE #{name}" if name && !name.empty?
    end
  end
end

port = Integer(ENV.fetch('PORT', '4318'))
server = TCPServer.new('127.0.0.1', port)
$stdout.sync = true
puts "COLLECTOR_LISTENING #{port}"

loop do
  conn = server.accept
  begin
    path, encoding, body = read_request(conn)
    next unless path

    puts "COLLECTOR_RECEIVED #{path} bytes=#{body.bytesize}"
    emit_trace_scopes(encoding, body) if path == '/v1/traces' && !body.empty?
    conn.write("HTTP/1.1 200 OK\r\nContent-Type: application/x-protobuf\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
  rescue StandardError => e
    puts "COLLECTOR_ERROR #{e.class}: #{e.message}"
  ensure
    conn.close
  end
end
