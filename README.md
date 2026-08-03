[![Gem Version](https://badge.fury.io/rb/dash0-opentelemetry.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/dash0-opentelemetry)

# Dash0 OpenTelemetry Distribution for Ruby

An opinionated, zero-code [OpenTelemetry](https://opentelemetry.io) distribution
for Ruby, published as the `dash0-opentelemetry` gem. It is a thin wrapper around
upstream OpenTelemetry Ruby that ships a batteries-included auto-instrumentation
setup for [Dash0](https://www.dash0.com).

## Intended use

This distribution is primarily intended to be injected into Ruby workloads by the
[Dash0 Kubernetes operator](https://github.com/dash0hq/dash0-operator), which
instruments them without code changes. It is required at process startup via
`RUBYOPT`, the Ruby analog of Node.js's `NODE_OPTIONS=--require`:

```sh
RUBYOPT="-r dash0-opentelemetry" ruby your_app.rb
RUBYOPT="-r dash0-opentelemetry" rails server
```

Everything runs as a side effect of requiring the gem — there is no API to call.
Because it is loaded before the application's own libraries, instrumentation is
installed lazily (via a `TracePoint`) as each supported library is loaded, so no
particular load order is required.

## Requirements

- Ruby **>= 3.3**. On an unsupported Ruby the distribution stands down cleanly
  (it logs a message and does nothing) rather than interfering with the app.

## Installation

```sh
gem install dash0-opentelemetry
```

Install it **outside** the application's bundle (it loads OpenTelemetry from its
own gem path, not from the app's `Gemfile`).

## What it does

On startup the distribution:

- exports **traces, metrics, and logs** over OTLP (HTTP/protobuf) to the Dash0
  collector at `${DASH0_OTEL_COLLECTOR_BASE_URL}/v1/{traces,metrics,logs}`;
- enables all instrumentations from
  [`opentelemetry-instrumentation-all`](https://github.com/open-telemetry/opentelemetry-ruby-contrib),
  installed lazily as their target libraries load;
- adds resource attributes: the upstream defaults (process, SDK, and any
  `OTEL_SERVICE_NAME` / `OTEL_RESOURCE_ATTRIBUTES`), the container detector
  (`container.id`), a Kubernetes pod-uid detector (`k8s.pod.uid`), a service-name
  fallback (`service.name`), and the distribution identity
  (`telemetry.distro.name = dash0-ruby`, `telemetry.distro.version`).

## Configuration

Behavior is driven entirely by environment variables: `DASH0_*` for
distribution-specific switches and standard `OTEL_*` for the rest.

### `DASH0_*` variables

| Variable | Description |
| --- | --- |
| `DASH0_OTEL_COLLECTOR_BASE_URL` | **Required.** Base URL of the OpenTelemetry collector to export to; each signal is sent to `<base>/v1/{traces,metrics,logs}`. If unset, the distribution stands down and exports nothing. (The Dash0 operator sets this for you.) |
| `DASH0_DISABLE` | Set to `true` to disable the distribution entirely. |
| `DASH0_AUTOMATIC_SERVICE_NAME` | Set to `false` to opt out of the automatic `service.name` fallback (see below). |
| `DASH0_BOOTSTRAP_SPAN` | If set to a non-empty string, a single internal span with that name is emitted immediately at startup. Useful for confirming the distribution is active. |
| `DASH0_FLUSH_ON_SIGTERM_SIGINT` | Set to `true` to install SIGTERM/SIGINT handlers that flush pending telemetry (timeboxed) before re-raising the signal. Do not use if the application installs its own handlers for these signals. |
| `DASH0_FLUSH_ON_EXIT` | Telemetry is flushed on normal process exit by default (via an `at_exit` hook). Set to `false` to disable this. |
| `DASH0_DEBUG` | Set to `true` for additional debug logging on stderr. |
| `DASH0_DEBUG_PRINT_SPANS` | Set to `true` to also print every span to stdout via a console exporter (in addition to exporting over OTLP). |

### Automatic service name

If no service name has been configured, the distribution derives one from the
application's own identity, in order of preference:

1. the app module in `config/application.rb` or `config/app.rb` (Rails, Hanami) —
   e.g. `module DemoApp` → `demo_app`;
2. `config.ru` — the `run <AppClass>` target or an inline application class
   (modular Sinatra, Roda, plain Rack, single-file Rails);
3. the entry script name, when it is not a known launcher/wrapper (e.g.
   `ruby my_worker.rb` → `my_worker`).

Because the distribution loads at interpreter startup, the entry point is usually
a wrapper (`bundle`, `puma`, `rackup`, …); these are deliberately ignored rather
than reported as the service name. When none of the above yields a name, the
distribution reports nothing and the SDK's `unknown_service` default stands.

This fallback is skipped entirely when a service name is already set via
`OTEL_SERVICE_NAME`, via a `service.name` in `OTEL_RESOURCE_ATTRIBUTES`, or when
`DASH0_AUTOMATIC_SERVICE_NAME=false`.

### `OTEL_*` variables

Standard OpenTelemetry variables are honored because the distribution uses the
stock OpenTelemetry SDK, exporters, and processors. Commonly useful ones:

| Variable | Description |
| --- | --- |
| `OTEL_SERVICE_NAME` | Sets `service.name` explicitly (and disables the automatic fallback). |
| `OTEL_RESOURCE_ATTRIBUTES` | Additional resource attributes as `key=value` pairs. A `service.name` here also disables the automatic fallback. |
| `OTEL_RUBY_ENABLED_INSTRUMENTATIONS` | Comma-separated allowlist of instrumentations to enable (by snake_case name, e.g. `net_http,rack`). When unset, all supported instrumentations are enabled. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Overrides the OTLP endpoint. Defaulted from `DASH0_OTEL_COLLECTOR_BASE_URL`; set explicitly only to override. |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | OTLP protocol; defaults to `http/protobuf` (the only protocol supported by the Ruby SDK's default path). |
| `OTEL_EXPORTER_OTLP_HEADERS` | Extra headers for the OTLP exporter (e.g. an authorization token when exporting directly to Dash0 rather than through the operator's collector). |
| `OTEL_METRIC_EXPORT_INTERVAL` / `OTEL_METRIC_EXPORT_TIMEOUT` | Periodic metric reader interval / timeout, in milliseconds. |

Standard batch-processor variables (`OTEL_BSP_*`, `OTEL_BLRP_*`) and
`OTEL_SDK_DISABLED` are honored by the underlying SDK as well.

### `DISALLOWED_LIB_PATH` (advanced)

A comma-separated list of bundled non-`opentelemetry-*` gems the distribution
should **not** put on the load path when injected. Its main use is the escape
hatch for a `google-protobuf` version clash: when instrumenting an app that uses
its own `google-protobuf` at runtime and breaks because the bundled version wins
set `DISALLOWED_LIB_PATH=google-protobuf` so the distribution defers to the app's
copy. Works while the app's protobuf is within the exporter's supported range;
otherwise the distribution stands down rather than crash.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md). Releasing is documented in
[RELEASING.md](RELEASING.md).

## License

[Apache-2.0](LICENSE)
