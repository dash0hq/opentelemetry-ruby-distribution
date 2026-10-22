# Configuration

The distribution is configured through environment variables, or through a [declarative configuration file](#declarative-configuration).
`DASH0_*` variables control distribution-specific behavior; standard `OTEL_*` variables control the OpenTelemetry SDK and exporters.

## Dash0 variables

| Variable | Description |
| --- | --- |
| `DASH0_OTEL_COLLECTOR_BASE_URL` | **Required** unless `OTEL_CONFIG_FILE` is set. Base URL of the OpenTelemetry collector. Each signal is exported to `<base>/v1/{traces,metrics,logs}`. If neither is set, the distribution stands down and exports nothing. |
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
| `OTEL_CONFIG_FILE` | Path to a [declarative configuration file](#declarative-configuration). When set, the file configures the SDK instead of environment variables. |
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

## Declarative configuration

Instead of environment variables, the OpenTelemetry SDK can be configured with an OpenTelemetry [declarative configuration file](https://opentelemetry.io/docs/languages/sdk-configuration/declarative-configuration/) by setting `OTEL_CONFIG_FILE` to its path.
The file is then the complete SDK configuration: it defines the resource, propagators, processors, readers, and exporters.
As the specification requires, other `OTEL_*` environment variables are ignored unless the file references them with `${VARIABLE}` substitution.

When both `OTEL_CONFIG_FILE` and `DASH0_OTEL_COLLECTOR_BASE_URL` are set, the configuration file takes precedence and `DASH0_OTEL_COLLECTOR_BASE_URL` is ignored, with a warning.

A file that exports all three signals to a collector looks like this:

```yaml
file_format: "1.0"
resource:
  attributes:
    - name: service.name
      value: ${OTEL_SERVICE_NAME:-unknown_service}
  detection/development:
    detectors:
      - container: {}
      - dash0_distribution: {}
      - dash0_kubernetes: {}
      - dash0_service_name: {}
propagator:
  composite:
    - tracecontext: {}
    - baggage: {}
tracer_provider:
  processors:
    - batch:
        exporter:
          otlp_http:
            endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}/v1/traces
meter_provider:
  readers:
    - periodic:
        exporter:
          otlp_http:
            endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}/v1/metrics
logger_provider:
  processors:
    - batch:
        exporter:
          otlp_http:
            endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}/v1/logs
```

A reference is written as `${NAME}`, `${env:NAME}`, or `${NAME:-default}`, where the default applies when the variable is unset or empty.
Use `$$` for a literal `$`.
Write a component without settings as `{}`, e.g. `batch: {}`; some components, such as processors, are ignored when written with no value at all.
Without a `propagator` section, trace context is not propagated.

These distribution settings still apply with a configuration file: `DASH0_DISABLE`, `DASH0_AUTOMATIC_SERVICE_NAME`, `DASH0_BOOTSTRAP_SPAN`, `DASH0_FLUSH_ON_SIGTERM_SIGINT`, `DASH0_FLUSH_ON_EXIT`, `DASH0_DEBUG`, and `OTEL_RUBY_ENABLED_INSTRUMENTATIONS`.
`DASH0_DEBUG_PRINT_SPANS` does not apply; add a `console: {}` exporter to the file instead.

If the file cannot be loaded, the distribution logs an error and the application keeps running without telemetry.
If the file sets `disabled: true`, the distribution installs nothing.

### Resource detectors

A configuration file can name these resource detectors under `resource.detection/development.detectors`:

| Detector | Description |
| --- | --- |
| `container` | Adds `container.id`. |
| `dash0_distribution` | Adds `telemetry.distro.name` and `telemetry.distro.version`. |
| `dash0_kubernetes` | Adds `k8s.pod.uid`. |
| `dash0_service_name` | Applies the [automatic service name](#automatic-service-name) when the file sets no `service.name`, or sets it to `unknown_service`. Uses `OTEL_SERVICE_NAME` if it is set. |

Attributes the file sets explicitly take precedence over detected ones.
Other detector names, including `host`, `process`, and `service`, are skipped with a warning.
Process attributes are always included.

### Unsupported settings

Some settings in the configuration schema are not supported by the Ruby SDK yet.
The distribution logs a warning and skips them.
These include `pull` metric readers, `otlp_grpc` and `otlp_file/development` exporters, `temporality_preference`, `default_histogram_aggregation`, and view `stream.attribute_keys`, `stream.name`, and `stream.description`.

## Advanced: DISALLOWED_LIB_PATH

`DISALLOWED_LIB_PATH` accepts a comma-separated list of gem name prefixes that the distribution should not add to the load path when injected.
Its primary use is to resolve a `google-protobuf` version conflict: when the application uses a different version of `google-protobuf` at runtime, set `DISALLOWED_LIB_PATH=google-protobuf` to let the application's copy take precedence.
If the application's version is incompatible with the OTLP exporter, the distribution stands down rather than crash.
