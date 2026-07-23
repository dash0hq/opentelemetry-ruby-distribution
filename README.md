# Dash0 OpenTelemetry Distribution for Ruby

An opinionated, zero-code [OpenTelemetry](https://opentelemetry.io) distribution
for Ruby, published as the `dash0-opentelemetry` gem. It is a thin wrapper around
upstream OpenTelemetry Ruby that ships a batteries-included auto-instrumentation
setup for [Dash0](https://www.dash0.com).

> **Status:** early development. This document will grow as functionality lands.

## Intended use

This distribution is primarily intended to be injected into Ruby workloads by the
[Dash0 Kubernetes operator](https://github.com/dash0hq/dash0-operator), which
instruments them without code changes. It is required at process startup via:

```sh
RUBYOPT="-r dash0-opentelemetry" ruby your_app.rb
```

## Configuration

Behavior is driven entirely by environment variables (`DASH0_*` for
distribution-specific switches and standard `OTEL_*` for the rest). The full list
will be documented here as the corresponding functionality is implemented.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache-2.0](LICENSE)
