# Changelog fragments

This directory holds one YAML fragment per user-facing change, following the
pattern used by the
[OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector/tree/main/.chloggen)
(`chloggen`). Editing `CHANGELOG.md` directly in every PR causes merge
conflicts and gets forgotten; a fragment per change avoids both.

## Adding a fragment

```sh
bundle exec rake chloggen:new[short-slug]
```

This copies [`TEMPLATE.yaml`](TEMPLATE.yaml) to `<short-slug>.yaml`. Fill in:

- `change_type` — one of `added`, `changed`, `deprecated`, `removed`, `fixed`,
  `security` (the [Keep a Changelog](https://keepachangelog.com) sections).
- `note` — a short, user-facing description, as it should read in
  `CHANGELOG.md`.
- `issues` — the GitHub issue and/or pull request number(s) the change relates
  to.

Commit the fragment alongside your change.

## Validating fragments

```sh
bundle exec rake chloggen:validate
```

CI runs this on every pull request. It also requires a fragment for changes that
reach users:

- `lib/` — the distribution's own code;
- `dash0-opentelemetry.gemspec` — the version constraints on the upstream
  OpenTelemetry gems we ship;
- `packaging/Gemfile.lock` — the exact closure installed into the bundle the
  injector mounts, so bumps of the shipped gems' *transitive* dependencies are
  covered too.

Anything else — dev/test tooling in the root `Gemfile`, CI, tests, docs — needs
no fragment, which is why dependency updates we do not ship (most dependabot
PRs) pass without one. A bump of the shipped closure does need a fragment: push
one onto the dependabot branch describing the update, or apply the
`Skip changelog` label. To check the same rule locally:

```sh
git diff --name-only origin/main...HEAD > /tmp/changed-files.txt
bundle exec rake "chloggen:required[/tmp/changed-files.txt]"
```

CI also fails a PR that edits `CHANGELOG.md` directly.

## Releasing

`bundle exec rake chloggen:update` merges every fragment into `CHANGELOG.md`'s
`Unreleased` section and deletes the fragments. See
[`RELEASING.md`](../RELEASING.md).
