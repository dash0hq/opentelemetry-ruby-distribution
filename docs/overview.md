# Dash0 OpenTelemetry Ruby Distribution

The Dash0 OpenTelemetry Ruby Distribution is an opinionated, zero-code [OpenTelemetry](https://opentelemetry.io) distribution published as the [`dash0-opentelemetry`](https://rubygems.org/gems/dash0-opentelemetry) gem.
It bundles the full set of upstream OpenTelemetry Ruby instrumentation libraries, configures sensible defaults for exporting to Dash0, and adds Dash0-specific resource detectors.
No code changes are required in the instrumented application.

## How it works

The distribution is loaded at interpreter startup via the `RUBYOPT` environment variable:

```sh
RUBYOPT="-r dash0-opentelemetry" ruby your_app.rb
```

Everything runs as a side effect of requiring the gem — there is no API to call.
The distribution configures the OpenTelemetry SDK, installs all supported instrumentations lazily (via a `TracePoint`), and begins exporting traces, metrics, and logs to the Dash0 collector.

## Key properties

- **Zero-code instrumentation.** No `Gemfile` changes, no initializer, no `SDK.configure` call.
- **Full instrumentation coverage.** All libraries in [`opentelemetry-instrumentation-all`](https://github.com/open-telemetry/opentelemetry-ruby-contrib) activate automatically as their target gems load.
- **OTLP/HTTP export.** Traces, metrics, and logs are exported over HTTP/protobuf to `${DASH0_OTEL_COLLECTOR_BASE_URL}/v1/{traces,metrics,logs}`.
- **Bundler-independent.** The distribution ships its own gem bundle and can be injected without modifying the application's `Gemfile` or `Gemfile.lock`.
- **Fail-open.** On an unsupported Ruby version, or if the distribution itself encounters an error, it stands down cleanly without interfering with the application.
- **Standard `OTEL_*` variables honored.** The distribution uses the upstream SDK and exporters, so all standard OpenTelemetry environment variables work as documented.

## Intended use

The distribution is primarily intended to be injected into Ruby workloads by the [Dash0 Kubernetes operator](https://github.com/dash0hq/dash0-operator), which sets `RUBYOPT` and the required environment variables without any application changes.
It can also be used directly — see [Getting started](getting-started).

## Requirements

Ruby 3.3 or later is required.
On an older Ruby the distribution logs a message and exits without affecting the application.
