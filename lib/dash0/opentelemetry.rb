# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'dash0/opentelemetry/version'
require 'dash0/opentelemetry/environment'
require 'dash0/opentelemetry/resource/distribution'
require 'dash0/opentelemetry/resource/kubernetes_pod'
require 'dash0/opentelemetry/resource/service_name_fallback'
require 'dash0/opentelemetry/instrumentation_installer'
require 'dash0/opentelemetry/sdk_configuration'
require 'dash0/opentelemetry/boot'

module Dash0
  # Namespace for the Dash0 OpenTelemetry distribution for Ruby.
  #
  # The distribution activates as a side effect of requiring the gem's entry
  # point (`require 'dash0-opentelemetry'`), typically via
  # `RUBYOPT="-r dash0-opentelemetry"`. Requiring this namespace on its own has no
  # side effects; the boot sequence is triggered explicitly via {boot!}.
  module OpenTelemetry
    # Prefix used for all messages the distribution writes to stderr.
    LOG_PREFIX = '[Dash0 OpenTelemetry Distribution]'

    # Boots the distribution. This is the single entry point that the requirable
    # entry file (`lib/dash0-opentelemetry.rb`) invokes.
    def self.boot!
      Boot.run
    end

    # Logs an error-level message to stderr. Always emitted.
    def self.log_error(message)
      warn "#{LOG_PREFIX} #{message}"
    end

    # Logs a debug-level message to stderr, only when DASH0_DEBUG=true.
    def self.log_debug(message)
      return unless Environment.debug?

      warn "#{LOG_PREFIX} #{message}"
    end
  end
end
