# Configuration

The distribution is configured entirely through environment variables.
`DASH0_*` variables control distribution-specific behavior; standard `OTEL_*` variables control the OpenTelemetry SDK and exporters.

## Dash0 variables

| Variable | Description |
| --- | --- |
| `DASH0_OTEL_COLLECTOR_BASE_URL` | **Required.** Base URL of the OpenTelemetry collector. Each signal is exported to `<base>/v1/{traces,metrics,logs}`. If unset, the distribution stands down and exports nothing. |
| `DASH0_DISABLE` | Set to `true` to disable the distribution entirely. |
| `DASH0_AUTOMATIC_SERVICE_NAME` | Set to `false` to opt out of the automatic `service.name` fallback (see below). |
| `DASH0_BOOTSTRAP_SPAN` | If set to a non-empty string, a span with that name is emitted once at startup. Useful for confirming the distribution is active. |
| `DASH0_FLUSH_ON_SIGTERM_SIGINT` | Set to `true` to install SIGTERM/SIGINT handlers that flush pending telemetry before re-raising the signal. Do not use if the application already installs handlers for these signals. |
| `DASH0_FLUSH_ON_EXIT` | Telemetry is flushed on process exit by default (via an `at_exit` hook). Set to `false` to disable. |
| `DASH0_DEBUG` | Set to `true` for additional debug logging on stderr. |
| `DASH0_DEBUG_PRINT_SPANS` | Set to `true` to print every span to stdout via a console exporter alongside the normal OTLP export. |

## OpenTelemetry variables

Standard OpenTelemetry environment variables are honored because the distribution uses the upstream SDK and exporters.
Commonly useful ones:

| Variable | Description |
| --- | --- |
| `OTEL_SERVICE_NAME` | Sets `service.name` explicitly. Also disables the automatic service name fallback. |
| `OTEL_RESOURCE_ATTRIBUTES` | Additional resource attributes as `key=value` pairs. A `service.name` here also disables the automatic fallback. |
| `OTEL_RUBY_ENABLED_INSTRUMENTATIONS` | Comma-separated allowlist of instrumentations to enable (by snake_case name, e.g. `net_http,rack`). When unset, all supported instrumentations are enabled. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Overrides the OTLP endpoint. Defaults to `DASH0_OTEL_COLLECTOR_BASE_URL`; set explicitly only to override. |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | OTLP protocol. Defaults to `http/protobuf` (the only protocol the Ruby SDK's default path supports). |
| `OTEL_EXPORTER_OTLP_HEADERS` | Extra headers for the OTLP exporter, e.g. an authorization token for direct Dash0 ingress. |
| `OTEL_METRIC_EXPORT_INTERVAL` | Periodic metric reader interval, in milliseconds. |
| `OTEL_METRIC_EXPORT_TIMEOUT` | Periodic metric reader timeout, in milliseconds. |

Standard batch-processor variables (`OTEL_BSP_*` for traces, `OTEL_BLRP_*` for logs) and `OTEL_SDK_DISABLED` are honored by the underlying SDK as well.

## Automatic service name

When no service name is configured, the distribution derives one from the application's own identity.
It checks, in order of preference:

1. The top-level `module <Name>` declaration in `config/application.rb` or `config/app.rb` (Rails, Hanami) — e.g. `module DemoApp` becomes `demo_app`.
2. An inline application class or a `run <AppClass>` target in `config.ru` (modular Sinatra, Roda, plain Rack, single-file Rails).
3. The entry script name (`$PROGRAM_NAME`), when it is not a known wrapper or launcher.

Known wrappers (`bundle`, `puma`, `rackup`, `rails`, `sidekiq`, and others) are deliberately skipped rather than used as a service name.
When none of these sources yields a useful name, the distribution leaves `service.name` unset and the SDK's `unknown_service` default stands.

The fallback is skipped entirely when `OTEL_SERVICE_NAME` is set, when `service.name` appears in `OTEL_RESOURCE_ATTRIBUTES`, or when `DASH0_AUTOMATIC_SERVICE_NAME=false`.

## Advanced: DISALLOWED_LIB_PATH

`DISALLOWED_LIB_PATH` accepts a comma-separated list of gem name prefixes that the distribution should not add to the load path when injected.
Its primary use is to resolve a `google-protobuf` version conflict: when the application uses a different version of `google-protobuf` at runtime, set `DISALLOWED_LIB_PATH=google-protobuf` to let the application's copy take precedence.
If the application's version is incompatible with the OTLP exporter, the distribution stands down rather than crash.
