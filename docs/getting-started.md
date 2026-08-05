# Getting started

The primary use case for this distribution is injection into Ruby workloads by the Dash0 Kubernetes operator, which performs everything described on this page for you.
If that is your intended use case, skip to [Kubernetes injection](kubernetes-injection).
Read on to install `dash0-opentelemetry` as a standalone gem, for example for local development or a deployment outside Kubernetes.

## Install the gem

Install `dash0-opentelemetry` **outside** the application's bundle:

```sh
gem install dash0-opentelemetry
```

The distribution ships its own gem closure (OpenTelemetry SDK, exporters, and all instrumentation libraries).
It must be installed outside the application bundle because it loads OpenTelemetry from its own gem path, not from the application's `Gemfile`.

## Start the application

Set two environment variables and start the application as usual:

```sh
export DASH0_OTEL_COLLECTOR_BASE_URL=http://your-collector:4318
export RUBYOPT="-r dash0-opentelemetry"
ruby your_app.rb
```

For Rails:

```sh
export DASH0_OTEL_COLLECTOR_BASE_URL=http://your-collector:4318
export RUBYOPT="-r dash0-opentelemetry"
rails server
```

On startup the distribution exports traces, metrics, and logs to `${DASH0_OTEL_COLLECTOR_BASE_URL}/v1/{traces,metrics,logs}`.

## Export directly to Dash0

To export directly to Dash0 without a local collector, use your organization's Dash0 ingress URL and an authorization token:

```sh
export DASH0_OTEL_COLLECTOR_BASE_URL=<your-dash0-ingress-url>
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <your-token>"
export RUBYOPT="-r dash0-opentelemetry"
rails server
```

## Startup sequence

When the application starts, the distribution:

1. Checks the Ruby version; stands down cleanly on Ruby older than 3.3.
2. Checks `DASH0_DISABLE`; stands down if set to `true`.
3. Checks `DASH0_OTEL_COLLECTOR_BASE_URL`; stands down if unset.
4. Checks whether the OpenTelemetry SDK is already loaded; stands down if so, to avoid double instrumentation.
5. Configures the OpenTelemetry SDK with OTLP/HTTP exporters and Dash0 resource attributes.
6. Installs all supported instrumentations for libraries already loaded, then installs a `TracePoint` to catch libraries loaded later.
7. Installs lifecycle handlers (SIGTERM/SIGINT flush if configured; `at_exit` flush by default).
