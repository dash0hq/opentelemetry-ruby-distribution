# Injection smoke test (Docker)

Verifies that the distribution loads and works **the way the operator/injector
deploys it**, something the `rake` suite (which runs under Bundler) can't cover:

- no Bundler; the OpenTelemetry gems are available only via a mounted bundle on
  `OTEL_RUBY_ADDITIONAL_GEM_PATH`;
- the entry is required through `RUBYOPT="-r .../opentelemetry-auto-instrumentation.rb"`
  (the fixed filename the injector requires, symlinked to the distro's entry);
- on both **glibc** and **musl**, so the native `google-protobuf` extension is
  exercised for each libc.

It boots the distribution, makes an instrumented `net/http` request (loaded after
preload, so this exercises the TracePoint sweep in the injected environment), and
asserts, by decoding the exported protobuf at the collector, that the span
carries the `OpenTelemetry::Instrumentation::Net::HTTP` scope. It also checks the
distro resource attributes are present and, as a bonus on real Linux, that
`container.id` is detected from cgroup. The collector is minimal (stdlib socket
plus the mounted bundle's proto classes for decoding).

## Run

```sh
test/docker/verify.sh
```

Requires Docker. Not part of `rake` (it needs Docker and network to build the
gem closure).

## Dependency pinning

The gem closure installed into the standalone bundle (`Dockerfile`) is pinned to
the exact versions recorded in `Gemfile.lock`, resolved from `Gemfile` against
the distro's own gemspec. This is what's shipped to the injector, so it's kept
reproducible across builds rather than floating on whatever's newest on
RubyGems. To pick up new compatible releases (e.g. after bumping a version
constraint in `../../dash0-opentelemetry.gemspec`):

```sh
BUNDLE_GEMFILE=test/docker/Gemfile bundle lock --update
```

Dependabot tracks the upstream `opentelemetry-*` constraints (see
`../../.github/dependabot.yml`) and will keep this lockfile in sync
automatically.

## Scope and what it does *not* cover

Runs on the host architecture only. To exercise amd64 on an arm64 host (or vice
versa), build with emulation, e.g.:

```sh
docker build --platform linux/amd64 --build-arg BASE=ruby:3.3-slim -t dash0-ruby-inject-glibc-amd64 test/docker
```

Still out of scope here (belongs in the injector / operator end-to-end):
the real injector `libotelinject.so`, the operator's injection webhook, a real
Kubernetes pod (`k8s.pod.uid`), and forking servers (Puma).
