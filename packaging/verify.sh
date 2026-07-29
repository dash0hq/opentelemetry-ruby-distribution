#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Host orchestration for the injection smoke test. Builds the gem, then builds and
# runs the injection image on both glibc and musl, verifying the distribution
# loads and works when injected without Bundler. Not part of `rake` (needs Docker).
#
# Usage: packaging/verify.sh

set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building gem"
(cd .. && gem build dash0-opentelemetry.gemspec >/dev/null)
mv ../dash0-opentelemetry-*.gem ./dash0-opentelemetry.gem
trap 'rm -f ./dash0-opentelemetry.gem' EXIT

status=0
run_variant() {
  name="$1"; base="$2"
  echo ""
  echo "==================== ${name} (${base}) ===================="
  docker build --quiet --build-arg "BASE=${base}" -t "dash0-ruby-inject-${name}" . >/dev/null
  if docker run --rm "dash0-ruby-inject-${name}"; then
    echo "==> ${name}: PASS"
  else
    echo "==> ${name}: FAIL"; status=1
  fi
}

run_variant glibc ruby:3.3-slim
run_variant musl ruby:3.3-alpine

echo ""
if [ "$status" -eq 0 ]; then echo "ALL VARIANTS PASSED"; else echo "SOME VARIANTS FAILED"; fi
exit "$status"
