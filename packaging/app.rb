# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# App for the Docker injection smoke test. The distribution is preloaded via the
# injector-style RUBYOPT, so the SDK is already configured. `net/http` is required
# here, after preload, so making a request exercises zero-code
# auto-instrumentation (the TracePoint sweep) in the injected environment, not
# just a manually created span. The resulting client span is flushed to the
# collector on exit; the collector asserts its instrumentation scope.

require 'net/http'
require 'uri'

Net::HTTP.get(URI("#{ENV.fetch('DASH0_OTEL_COLLECTOR_BASE_URL')}/ping"))

attributes = OpenTelemetry.tracer_provider.instance_variable_get(:@resource).instance_variable_get(:@attributes)
puts "APP_RESOURCE telemetry.distro.name=#{attributes['telemetry.distro.name']} " \
     "telemetry.distro.version=#{attributes['telemetry.distro.version']} " \
     "container.id=#{attributes['container.id']}"
puts "APP_PLATFORM #{RUBY_PLATFORM}"
puts 'APP_DONE'
