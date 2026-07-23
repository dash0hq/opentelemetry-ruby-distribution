# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'dash0/opentelemetry/version'

module Dash0
  # Namespace for the Dash0 OpenTelemetry distribution for Ruby.
  #
  # The distribution activates as a side effect of requiring the gem's entry
  # point (`require 'dash0-opentelemetry'`), typically via
  # `RUBYOPT="-r dash0-opentelemetry"`. Loading this namespace on its own has no
  # side effects; the boot sequence is triggered explicitly by the entry point.
  module OpenTelemetry
    # Log prefix used for all messages the distribution writes to stderr.
    LOG_PREFIX = '[Dash0 OpenTelemetry Distribution]'

    # Boots the distribution. This is the single entry point that the requirable
    # entry file (`lib/dash0-opentelemetry.rb`) invokes.
    #
    # Currently a no-op placeholder; the gating, SDK configuration, and
    # instrumentation install are implemented in later phases.
    def self.boot!
      # Intentionally left blank for now — see the phased implementation plan.
      nil
    end
  end
end
