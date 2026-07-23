# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    # Orchestrates startup: gating (disable switch, mandatory collector URL,
    # double-instrumentation guard), SDK configuration, and instrumentation
    # install.
    #
    # The Ruby-version stand-down lives in the requirable entry point
    # (`lib/dash0-opentelemetry.rb`) so it can run before any modern-syntax file
    # is required.
    module Boot
      COLLECTOR_BASE_URL_ENV = 'DASH0_OTEL_COLLECTOR_BASE_URL'
      DISABLE_ENV = 'DASH0_DISABLE'

      class << self
        # Boots the distribution. Safe to call more than once; only the first call
        # that passes the gates takes effect.
        def run
          return if @booted
          return if disabled?

          base_url = collector_base_url
          return unless base_url

          if already_instrumented?
            Dash0::OpenTelemetry.log_error(
              'The application already has OpenTelemetry loaded; standing down to avoid double instrumentation.'
            )
            return
          end

          @booted = true
          configure(base_url)
        end

        # Resets the one-time boot guard. Intended for tests only.
        def reset_for_testing!
          @booted = false
        end

        def booted?
          @booted == true
        end

        private

        def configure(base_url)
          SdkConfiguration.apply(base_url: base_url)
          InstrumentationInstaller.start
          Dash0::OpenTelemetry.log_debug("Distribution initialized (collector base URL: #{base_url}).")
        rescue StandardError => e
          @booted = false
          Dash0::OpenTelemetry.log_error("Initialization failed: #{e.message}")
        end

        def disabled?
          return false unless Environment.opted_in?(DISABLE_ENV)

          Dash0::OpenTelemetry.log_error(
            "#{DISABLE_ENV} is set to true; the distribution is disabled. OpenTelemetry data will not be sent to Dash0."
          )
          true
        end

        # The mandatory collector base URL, or nil (with an explanatory log) when
        # unset. There is no default in code - the operator supplies it.
        def collector_base_url
          value = ENV.fetch(COLLECTOR_BASE_URL_ENV, nil)
          if value.nil? || value.strip.empty?
            Dash0::OpenTelemetry.log_error(
              "#{COLLECTOR_BASE_URL_ENV} is not set; there is nowhere to export to. " \
              'OpenTelemetry data will not be sent to Dash0.'
            )
            return nil
          end
          value.strip
        end

        # Detects whether OpenTelemetry's SDK was already loaded by the application
        # (e.g. the app bundles and initializes OpenTelemetry itself). Checked
        # before we require the SDK ourselves.
        def already_instrumented?
          sdk_loaded?
        end

        def sdk_loaded?(loaded_features = $LOADED_FEATURES)
          loaded_features.any? { |path| path.end_with?('lib/opentelemetry/sdk.rb') }
        end
      end
    end
  end
end
