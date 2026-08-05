# Kubernetes injection

The Dash0 Kubernetes operator injects the distribution into Ruby workloads automatically, without any code changes.
This page describes the injection mechanism and the safety checks the distribution performs at startup.

## How injection works

The operator mounts a standalone gem bundle into each pod and sets environment variables:

- `RUBYOPT="-r <absolute path to lib/dash0-opentelemetry.rb>"` — causes Ruby to require the distribution before running any application code.
- `OTEL_RUBY_ADDITIONAL_GEM_PATH=<mounted bundle path>` — tells the distribution where to find its bundled gems (OpenTelemetry SDK, exporters, and instrumentations) without relying on Bundler.
- `DASH0_OTEL_COLLECTOR_BASE_URL` — the collector endpoint to export to.

The injected bundle is isolated from the application's own `Gemfile`; no application dependencies are modified.

## Safety checks

Before activating, the distribution performs three checks:

**Ruby version check.**
The entry point (`lib/dash0-opentelemetry.rb`) uses syntax compatible with older Rubies and checks the runtime version before requiring any other file.
On Ruby older than 3.3, it logs a message to stderr and exits cleanly without affecting the application.

**Double-instrumentation guard.**
The distribution checks whether the OpenTelemetry SDK is already loaded (i.e. the application bundles and initializes OpenTelemetry itself).
If it is, the distribution logs a message and stands down to avoid conflicting with the application's own setup.

**Missing collector URL.**
If `DASH0_OTEL_COLLECTOR_BASE_URL` is not set, the distribution logs a message and stands down rather than export to nowhere.

## Graceful stand-down

All safety checks fail open: the distribution logs a message on stderr and returns without raising an exception, so the application starts normally in all cases.

## DISALLOWED_LIB_PATH

When injected, the distribution puts its bundled gems on the load path using `OTEL_RUBY_ADDITIONAL_GEM_PATH`.
`DISALLOWED_LIB_PATH` (comma-separated gem name prefixes) excludes specific non-`opentelemetry-*` gems from the load path, providing an escape hatch for version conflicts with the application.

The most common case is a `google-protobuf` conflict: when the application already loads a different version of `google-protobuf` at runtime, set `DISALLOWED_LIB_PATH=google-protobuf` to let the application's version win.
If the application's version is incompatible with the OTLP exporter, the distribution stands down rather than crash.
