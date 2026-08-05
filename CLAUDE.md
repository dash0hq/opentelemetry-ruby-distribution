# CLAUDE.md

Maintenance instructions for the Dash0 OpenTelemetry Ruby Distribution.

## Project overview

This is a Ruby gem (`dash0-opentelemetry`) that auto-instruments Ruby applications
via `RUBYOPT="-r dash0-opentelemetry"`.
All code lives under `lib/`.
The gem is primarily injected by the Dash0 Kubernetes operator; the `packaging/`
directory holds the standalone gem bundle the operator mounts into pods.

Key modules:

- `lib/dash0-opentelemetry.rb` — entry point; Ruby-version gate lives here so it
  can run on older Rubies before requiring any other file.
- `lib/dash0/opentelemetry/boot.rb` — orchestrates startup gates and calls into
  SDK configuration, instrumentation installer, and lifecycle setup.
- `lib/dash0/opentelemetry/environment.rb` — helpers for reading env vars.
- `lib/dash0/opentelemetry/sdk_configuration.rb` — configures OpenTelemetry SDK,
  sets OTLP exporter defaults, builds the resource.
- `lib/dash0/opentelemetry/instrumentation_installer.rb` — lazy instrumentation
  via `TracePoint(:end)`.
- `lib/dash0/opentelemetry/lifecycle.rb` — bootstrap span, SIGTERM/SIGINT handlers,
  `at_exit` flush.
- `lib/dash0/opentelemetry/resource/` — three custom resource detectors:
  `distribution.rb`, `kubernetes_pod.rb`, `service_name_fallback.rb`.

## Coding conventions

- SPDX header on every file: `# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.`
  and `# SPDX-License-Identifier: Apache-2.0`.
- Ruby >= 3.3 may be assumed in all files under `lib/dash0/` (but not in
  `lib/dash0-opentelemetry.rb`, which must stay parse-safe on older Rubies).
- Fail open: catch `StandardError, ScriptError` at startup boundaries and log
  rather than raise.
- Use `Environment.set_default` (never `ENV[name] =`) when setting OTLP defaults,
  so an explicit operator/user value is never overwritten.
- Instrumentation names in user-facing text use snake_case (e.g. `net_http`,
  `active_record`).

## Source of truth for each doc

When the code changes, update the corresponding doc.

| Doc | Authoritative source file(s) |
| --- | --- |
| `docs/overview.md` | `README.md`, `lib/dash0-opentelemetry.rb`, `dash0-opentelemetry.gemspec` |
| `docs/getting-started.md` | `README.md` |
| `docs/configuration.md` | `lib/dash0/opentelemetry/environment.rb`, `lib/dash0/opentelemetry/sdk_configuration.rb`, `lib/dash0/opentelemetry/lifecycle.rb`, `lib/dash0/opentelemetry/resource/service_name_fallback.rb` |
| `docs/auto-instrumentation.md` | `packaging/Gemfile.lock`, `lib/dash0/opentelemetry/instrumentation_installer.rb` |
| `docs/resource-detection.md` | `lib/dash0/opentelemetry/resource/distribution.rb`, `lib/dash0/opentelemetry/resource/kubernetes_pod.rb`, `lib/dash0/opentelemetry/resource/service_name_fallback.rb`, `lib/dash0/opentelemetry/sdk_configuration.rb` |
| `docs/kubernetes-injection.md` | `lib/dash0-opentelemetry.rb`, `lib/dash0/opentelemetry/boot.rb`, `lib/dash0/opentelemetry/sdk_configuration.rb` |

## Rules for updating docs

**When a `DASH0_*` or `OTEL_*` env var is added, removed, or renamed:**
Update `docs/configuration.md`.
Also update `docs/getting-started.md` if the startup sequence changes.
Also update `docs/kubernetes-injection.md` if injection-specific behavior changes.

**When a resource detector is added, changed, or removed:**
Update `docs/resource-detection.md`.
Also update `docs/overview.md` if the resource attribute summary there changes.

**When the instrumentation list changes** (i.e. `opentelemetry-instrumentation-all`
is updated in `dash0-opentelemetry.gemspec` and `packaging/Gemfile.lock` is
regenerated):
Derive `docs/auto-instrumentation.md`'s instrumentation tables from
`packaging/Gemfile.lock`.
The direct dependencies of `opentelemetry-instrumentation-all` are the canonical
source; extract them with:

```sh
grep -A 200 'opentelemetry-instrumentation-all (' packaging/Gemfile.lock \
  | grep -E '^\s+opentelemetry-instrumentation-' \
  | sed 's/.*opentelemetry-instrumentation-//' \
  | sed 's/ (.*//' \
  | sort
```

Never update the instrumentation tables by hand.

**When injection behavior changes** (startup gates, RUBYOPT mechanism,
OTEL_RUBY_ADDITIONAL_GEM_PATH, DISALLOWED_LIB_PATH):
Update `docs/kubernetes-injection.md` and `docs/configuration.md`.

## Keeping transformations.yaml in sync

`.github/workflows/sync-docs/transformations.yaml` must list every file under
`docs/*.md` in the `files:` block.
The `coverage:` block enforces this in CI, so adding a doc file without updating
`transformations.yaml` will break the sync workflow.
When adding a new doc:
1. Add a `- source: / target: / title:` entry to the `files:` block.
2. Update the source-of-truth table in this file.
3. Update `docs/overview.md` if the new page warrants a mention.

## Style rules for docs

- One sentence per line in the Markdown source (not one sentence per paragraph).
- Sentence-case headings (capitalize only the first word and proper nouns).
- Active voice.
- Inline code (backticks) for all variable names, gem names, file paths, env vars,
  and instrumentation names.
- No em-dashes; use a comma, semicolon, or rewrite the sentence.
- Three-column tables for instrumentation lists: Library | Gem | Instrumentation name.
- Two-column tables for env var lists: Variable | Description.
- No trailing whitespace, no blank lines inside table rows.
