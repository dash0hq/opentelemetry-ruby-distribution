# Resource detection

The distribution builds the OpenTelemetry resource from several detectors applied in order.
Later detectors take precedence on attribute key conflicts, except for the distribution identity attributes, which are always applied last.

## Upstream detectors

The SDK adds process and SDK attributes automatically.
The upstream `container` detector (`opentelemetry-resource-detector-container`) adds `container.id` by reading the container's cgroup file.

## Dash0 detectors

### Distribution identity

The `Distribution` detector always adds:

| Attribute | Value |
| --- | --- |
| `telemetry.distro.name` | `dash0-ruby` |
| `telemetry.distro.version` | The installed gem version |

### Kubernetes pod UID

The `KubernetesPod` detector adds `k8s.pod.uid` when the process is running inside a Kubernetes pod.

It first checks `/etc/hosts` for the `# Kubernetes-managed hosts file` marker to confirm a pod context.
If the marker is present, it reads the pod UID from cgroup files:

- **cgroup v1:** parses `/proc/self/mountinfo` for a mount path containing `/pods/<uid>`.
- **cgroup v2:** parses `/proc/self/cgroup` for the penultimate segment of each cgroup line, which encodes the pod UID in slice notation (e.g. `kubepods-pod<uid>.slice`, with underscores normalized to dashes).

If neither file yields a UID, the detector adds no attribute and fails silently.

### Service name fallback

The `ServiceNameFallback` detector provides a `service.name` when none has been configured.
It checks, in order:

1. The top-level `module <Name>` declaration in `config/application.rb` or `config/app.rb` (Rails, Hanami).
2. An inline application class or a `run <AppClass>` target in `config.ru` (modular Sinatra, Roda, plain Rack, single-file Rails).
3. The entry script name (`$PROGRAM_NAME`), when it is not a known wrapper.

Known wrappers (`bundle`, `puma`, `rackup`, `rails`, `sidekiq`, and others) are deliberately skipped rather than used as a service name.
When none of these sources yields a useful name, the detector adds no attribute and the SDK's `unknown_service` default stands.

The fallback is skipped entirely when `OTEL_SERVICE_NAME` is set, when `service.name` appears in `OTEL_RESOURCE_ATTRIBUTES`, or when `DASH0_AUTOMATIC_SERVICE_NAME=false`.
