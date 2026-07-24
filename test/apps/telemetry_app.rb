# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# Sample app for integration tests. The distribution is preloaded via
# `ruby -r dash0-opentelemetry`, so the SDK is already configured here. Emit one
# span, one metric, and one log, then exit — the distribution's at-exit flush
# exports everything before the process terminates.

OpenTelemetry.tracer_provider.tracer('telemetry-app').in_span('work') do |span|
  span.set_attribute('app.attribute', 'value')
end

OpenTelemetry.meter_provider.meter('telemetry-app').create_counter('app.requests').add(1)

OpenTelemetry.logger_provider.logger(name: 'telemetry-app').on_emit(
  severity_text: 'INFO',
  body: 'hello from telemetry-app'
)
