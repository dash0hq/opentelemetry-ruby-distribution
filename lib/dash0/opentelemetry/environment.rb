# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    # Helpers for reading and defaulting environment variables. The distribution
    # is configured entirely through the environment (`DASH0_*` switches and
    # standard `OTEL_*` variables).
    module Environment
      module_function

      # True when the variable is set to "true" (case-insensitive, trimmed).
      def opted_in?(name)
        ENV.fetch(name, '').strip.casecmp('true').zero?
      end

      # True when the variable is set to "false" (case-insensitive, trimmed).
      def opted_out?(name)
        ENV.fetch(name, '').strip.casecmp('false').zero?
      end

      # True when the variable is set to a non-empty (trimmed) value.
      def present?(name)
        value = ENV.fetch(name, nil)
        !value.nil? && !value.strip.empty?
      end

      # Sets +name+ to +value+ unless it already has a non-empty value. This lets
      # the distribution provide defaults without ever overriding a value the
      # application or operator set explicitly.
      def set_default(name, value)
        ENV[name] = value unless present?(name)
      end

      # Parses an integer environment variable, falling back to +default+ when
      # unset or not a valid integer.
      def integer(name, default)
        value = ENV.fetch(name, nil)
        return default if value.nil? || value.strip.empty?

        Integer(value.strip)
      rescue ArgumentError
        default
      end

      def debug?
        opted_in?('DASH0_DEBUG')
      end
    end
  end
end
