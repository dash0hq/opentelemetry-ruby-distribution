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
- Custom resource detectors: `kubernetes-pod` (derives `k8s.pod.uid` from cgroup
  v1/v2, gated on the `/etc/hosts` Kubernetes marker) and `service-name-fallback`
  (derives `service.name` from the program entry point unless one is already set
  via `OTEL_SERVICE_NAME` / `OTEL_RESOURCE_ATTRIBUTES`, or opted out with
  `DASH0_AUTOMATIC_SERVICE_NAME=false`). The upstream container detector
  (`container.id`) now runs by default too.
- Lifecycle handling: `DASH0_BOOTSTRAP_SPAN` emits a named internal span at
  startup; `DASH0_FLUSH_ON_SIGTERM_SIGINT=true` installs SIGTERM/SIGINT handlers
  that flush telemetry (timeboxed) and re-raise the signal; an at-exit flush runs
  by default unless disabled with `DASH0_FLUSH_ON_EXIT=false`.
  Provider shutdown is idempotent and runs off the trap context to stay
  mutex-safe.
- Integration test harness: an in-process mock OTLP/HTTP collector (decoding the
  exporter's protobuf payloads) and sample apps run in a separate process with
  the distribution preloaded via `ruby -r dash0-opentelemetry`. Covers
  end-to-end export of all three signals with the distro resource attributes,
  zero-code `net/http` auto-instrumentation, a minimal Rails app (proving the
  Rack/Rails stack is instrumented when loaded after preload), and the
  unsupported-Ruby stand-down.
- Documentation and release tooling: a full environment-variable reference in the
  README, `RELEASING.md`, and a RubyGems trusted-publishing (`release.yml`)
  workflow triggered on version tags.
- Injection support: when preloaded by the operator/injector (no Bundler, gems
  mounted on `OTEL_RUBY_ADDITIONAL_GEM_PATH`), the entry point now puts its own
  `lib` and the bundled OpenTelemetry gems on the load path, so the distribution
  loads without relying on Bundler or gem activation.
