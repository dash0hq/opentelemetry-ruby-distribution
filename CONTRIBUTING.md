# Contributing

Thanks for your interest in the Dash0 OpenTelemetry distribution for Ruby.

## Development setup

Use the Ruby version declared in the gemspec (`>= 3.3`). Then:

```sh
bundle install
```

## Common tasks

- `bundle exec rake` — run the full verification (unit tests + RuboCop). This is
  what CI runs.
- `bundle exec rake test` — run the unit tests only.
- `bundle exec rake rubocop` — run the linter only.
- `bundle exec rubocop -a` — auto-correct lint offenses where safe.

## Conventions

- Every Ruby source file starts with the SPDX header:

  ```ruby
  # frozen_string_literal: true

  # SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
  # SPDX-License-Identifier: Apache-2.0
  ```

- Tests use Minitest and live under `test/`, named `*_test.rb`.
- This distribution is a **wrapper** around upstream OpenTelemetry Ruby. Prefer
  configuring or extending upstream behavior over reimplementing it.

## Changelog

User-facing changes need a changelog fragment instead of a direct edit to
`CHANGELOG.md`:

```sh
bundle exec rake chloggen:new[short-slug]
```

Fill in the generated `.chloggen/<short-slug>.yaml` and commit it alongside
your change. See [`.chloggen/README.md`](.chloggen/README.md) for the fragment
format; CI validates fragments and requires one for changes under `lib/`
(skippable with the `Skip changelog` label).

## How it is used

The distribution is designed to be injected into Ruby workloads by the Dash0
Kubernetes operator via `RUBYOPT="-r dash0-opentelemetry"`, the Ruby analog of
Node's `NODE_OPTIONS=--require`. Everything runs as a side effect of requiring
the gem; there is no API to call.
