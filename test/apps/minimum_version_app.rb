# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# Simulates running on an unsupported Ruby by raising the minimum version above
# the current one before requiring the entry point. The entry must stand down
# (return before loading the rest of the distribution) rather than crash. This
# app requires the distribution itself, so it is NOT run with `-r`.

require 'dash0/opentelemetry/version'

Dash0::OpenTelemetry.send(:remove_const, :MINIMUM_RUBY_VERSION)
Dash0::OpenTelemetry::MINIMUM_RUBY_VERSION = '99.0.0'

require 'dash0-opentelemetry'

# If the entry stood down, the rest of the distribution was never loaded.
puts "BOOT_DEFINED=#{defined?(Dash0::OpenTelemetry::Boot) ? 'yes' : 'no'}"
