# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    # Process-lifecycle concerns: an optional bootstrap span at startup, and
    # graceful flushing of pending telemetry on shutdown.
    module Lifecycle
      BOOTSTRAP_SPAN_ENV = 'DASH0_BOOTSTRAP_SPAN'
      FLUSH_ON_SIGNALS_ENV = 'DASH0_FLUSH_ON_SIGTERM_SIGINT'
      FLUSH_ON_EXIT_ENV = 'DASH0_FLUSH_ON_EXIT'

      # Name of the tracer used for the bootstrap span.
      BOOTSTRAP_TRACER = 'dash0-ruby-distribution'

      # Per-provider shutdown timeout (seconds). Bounds how long process exit can
      # block flushing telemetry to a slow or unreachable collector.
      SHUTDOWN_TIMEOUT_SECONDS = 2.0

      # Signals whose default action would otherwise terminate the process without
      # running `at_exit`, so we flush explicitly before re-raising.
      FLUSH_SIGNALS = %w[TERM INT].freeze

      @shutdown_mutex = Mutex.new
      @shutdown_done = false

      class << self
        # Installs the configured lifecycle behaviors. Called once, after the SDK
        # has been configured.
        def install
          name = bootstrap_span_name
          create_bootstrap_span(name) if name
          install_signal_handlers if flush_on_signals?
          install_exit_handler if flush_on_exit?
        end

        # Gracefully shuts down the tracer, meter, and logger providers, flushing
        # pending telemetry. Idempotent: only the first call performs the shutdown.
        def shutdown
          @shutdown_mutex.synchronize do
            return if @shutdown_done

            @shutdown_done = true
          end

          providers.each do |provider|
            provider.shutdown(timeout: SHUTDOWN_TIMEOUT_SECONDS)
          rescue StandardError => e
            Dash0::OpenTelemetry.log_debug("Error during provider shutdown: #{e.message}")
          end
        end

        def shutdown?
          @shutdown_done
        end

        # Resets the one-time shutdown guard. Intended for tests only.
        def reset_for_testing!
          @shutdown_done = false
        end

        private

        def bootstrap_span_name
          Environment.present?(BOOTSTRAP_SPAN_ENV) ? ENV.fetch(BOOTSTRAP_SPAN_ENV).strip : nil
        end

        def flush_on_signals?
          Environment.opted_in?(FLUSH_ON_SIGNALS_ENV)
        end

        # On by default; disabled only by an explicit opt-out.
        def flush_on_exit?
          !Environment.opted_out?(FLUSH_ON_EXIT_ENV)
        end

        def create_bootstrap_span(name)
          ::OpenTelemetry.tracer_provider.tracer(BOOTSTRAP_TRACER).in_span(name, kind: :internal) { nil }
        rescue StandardError => e
          Dash0::OpenTelemetry.log_debug("Could not create bootstrap span: #{e.message}")
        end

        # Installs SIGTERM/SIGINT handlers that flush, then re-raise the signal so
        # the process terminates with the expected disposition. The shutdown runs
        # in a fresh thread because a signal trap runs in a restricted context
        # where acquiring the SDK's mutexes would raise; a thread body escapes it.
        #
        # Signal handlers can only be installed from the main thread; if we are not
        # on it, skip them rather than raise (the at-exit flush still applies).
        def install_signal_handlers
          return unless Thread.current == Thread.main

          FLUSH_SIGNALS.each do |signal|
            Signal.trap(signal) do
              Thread.new { shutdown }.join
              Signal.trap(signal, 'DEFAULT')
              Process.kill(signal, Process.pid)
            end
          end
        rescue ArgumentError => e
          Dash0::OpenTelemetry.log_debug("Could not install signal handlers: #{e.message}")
        end

        def install_exit_handler
          at_exit { shutdown }
        end

        # The configured SDK providers that can be shut down. When a signal's SDK
        # is not installed, `OpenTelemetry` may not define the accessor at all, and
        # API no-op providers do not respond to `shutdown`; both are skipped.
        def providers
          %i[tracer_provider meter_provider logger_provider].filter_map do |name|
            next unless ::OpenTelemetry.respond_to?(name)

            provider = ::OpenTelemetry.public_send(name)
            provider if provider.respond_to?(:shutdown)
          end
        end
      end
    end
  end
end
