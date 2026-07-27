#!/bin/sh
# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0
#
# In-container orchestration for the injection smoke test: start the stdlib
# collector, run the app exactly as the operator/injector would (Bundler-less,
# gems only on OTEL_RUBY_ADDITIONAL_GEM_PATH, entry via RUBYOPT), and assert the
# distribution booted, instrumented, detected resources, and exported.

set -eu
mkdir -p /tmp/empty

# The collector decodes the OTLP protobuf, so it needs the proto classes and the
# native google-protobuf for this libc, both available in the mounted bundle.
env GEM_HOME=/otel-ruby GEM_PATH=/otel-ruby ruby /work/mini_collector.rb >/tmp/collector.log 2>&1 &
collector_pid=$!

# Wait for the collector to bind.
i=0
while [ "$i" -lt 50 ]; do
  grep -q COLLECTOR_LISTENING /tmp/collector.log && break
  i=$((i + 1)); sleep 0.1
done
if ! grep -q COLLECTOR_LISTENING /tmp/collector.log; then
  echo "FATAL: collector did not start within 5s"
  cat /tmp/collector.log
  kill "$collector_pid" 2>/dev/null || true
  exit 1
fi

# Run the app the way the injector does: no Bundler, scrubbed gem paths, the OTel
# gems available only via the mounted bundle, the entry required through RUBYOPT.
set +e
env GEM_HOME=/tmp/empty GEM_PATH=/tmp/empty \
  OTEL_RUBY_ADDITIONAL_GEM_PATH=/otel-ruby \
  RUBYOPT="-r /otel-ruby/opentelemetry-auto-instrumentation.rb" \
  DASH0_OTEL_COLLECTOR_BASE_URL=http://127.0.0.1:4318 \
  DASH0_DEBUG=true \
  ruby /work/app.rb >/tmp/app.log 2>&1
app_exit=$?
set -e

sleep 0.3
kill "$collector_pid" 2>/dev/null || true

echo "===== app.log ====="; cat /tmp/app.log
echo "===== collector.log ====="; cat /tmp/collector.log
echo "===== checks ====="

fail=0
check() { if eval "$2"; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }

check "app exited 0"                  "[ $app_exit -eq 0 ]"
check "distribution booted"           "grep -q 'Distribution initialized' /tmp/app.log"
check "app body completed"            "grep -q 'APP_DONE' /tmp/app.log"
check "distro resource present"       "grep -q 'telemetry.distro.name=dash0-ruby' /tmp/app.log"
check "traces exported to collector"  "grep -q 'COLLECTOR_RECEIVED /v1/traces' /tmp/collector.log"
check "net/http auto-instrumented"    "grep -q 'COLLECTOR_SCOPE OpenTelemetry::Instrumentation::Net::HTTP' /tmp/collector.log"

if [ "$fail" -eq 0 ]; then
  echo "PASS ($(ruby -e 'print RUBY_PLATFORM'))"
else
  echo "FAILED"; exit 1
fi
