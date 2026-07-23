# Changelog

All notable changes to the Dash0 OpenTelemetry distribution for Ruby will be
documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffolding: gem layout, tooling (RuboCop, Minitest, Rake),
  and CI.
- Boot sequence and gating: stands down on unsupported Ruby (parse-safe guard in
  the entry point), when `DASH0_DISABLE=true`, when
  `DASH0_OTEL_COLLECTOR_BASE_URL` is unset, and when OpenTelemetry is already
  loaded (double-instrumentation guard).
- Trace export: configures the OpenTelemetry SDK with an OTLP/HTTP-protobuf
  exporter derived from `DASH0_OTEL_COLLECTOR_BASE_URL`, plus the
  `telemetry.distro.{name,version}` resource attributes (`dash0-ruby`).
- Zero-code instrumentation install via a `TracePoint(:end)` sweep, so libraries
  loaded after startup are instrumented; honors
  `OTEL_RUBY_ENABLED_INSTRUMENTATIONS`.
- Metrics and logs export over OTLP/HTTP-protobuf to `/v1/metrics` and
  `/v1/logs` on the same collector base URL, activated by requiring the metrics
  and logs SDK gems. Metric export interval/timeout honor
  `OTEL_METRIC_EXPORT_INTERVAL` / `OTEL_METRIC_EXPORT_TIMEOUT` (via the upstream
  periodic reader).
- `DASH0_DEBUG_PRINT_SPANS=true` prints spans to stdout via a console exporter,
  added alongside (not in place of) the OTLP exporter.
