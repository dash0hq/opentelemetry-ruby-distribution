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

CI runs this on every pull request, and requires a fragment for changes under
`lib/` (skippable with the `skip-changelog` label).

## Releasing

`bundle exec rake chloggen:update` merges every fragment into `CHANGELOG.md`'s
`Unreleased` section and deletes the fragments. See
[`RELEASING.md`](../RELEASING.md).
