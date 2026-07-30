# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    # Installs per-library instrumentation lazily via a `TracePoint(:end)`: an
    # initial sweep for already-loaded libraries, then a re-sweep each time a class
    # or module finishes being defined, so a library loaded after us is still
    # caught.
    #
    # Ported, with light adaptation, from the upstream
    # `opentelemetry-auto-instrumentation` gem's `OTelInitializer`
    # (open-telemetry/opentelemetry-ruby-instrumentation), Apache-2.0.
    module InstrumentationInstaller
      @mutex = Mutex.new
      @trace_point = nil

      class << self
        # Sweeps once for already-loaded libraries, then — unless everything
        # relevant is already installed — installs a TracePoint(:end) that
        # re-sweeps whenever a class or module finishes being defined.
        #
        # @param [Array<String>] enabled_names canonical instrumentation names to
        #   restrict installation to; empty means "all registered".
        def start(enabled_names = enabled_instrumentation_names)
          sweep(enabled_names)
          return if relevant_instrumentations(enabled_names).all?(&:installed?)

          @trace_point = TracePoint.new(:end) { sweep(enabled_names) }
          @trace_point.enable
        end

        # Exposed for testing/inspection.
        attr_reader :trace_point

        # Returns the canonical instrumentation names enabled via
        # OTEL_RUBY_ENABLED_INSTRUMENTATIONS, or [] when the variable is unset
        # (meaning: install everything registered).
        def enabled_instrumentation_names
          raw = ENV['OTEL_RUBY_ENABLED_INSTRUMENTATIONS'].to_s
          return [] if raw.strip.empty?

          lookup = registry_lookup
          raw.split(',').filter_map do |entry|
            normalized = entry.strip.downcase
            canonical = lookup[normalized]
            if canonical.nil? && ENV['DASH0_DEBUG'] == 'true'
              warn "#{Dash0::OpenTelemetry::LOG_PREFIX} Unknown instrumentation '#{entry.strip}'"
            end
            canonical
          end
        end

        private

        # Installs every relevant instrumentation that is installable right now.
        def sweep(enabled_names)
          @mutex.synchronize do
            ready = relevant_instrumentations(enabled_names).select do |instrumentation|
              ready_to_install?(instrumentation)
            end
            ::OpenTelemetry::Instrumentation.registry.install(ready.map(&:name)) unless ready.empty?
          end
        rescue StandardError => e
          if ENV['DASH0_DEBUG'] == 'true'
            warn "#{Dash0::OpenTelemetry::LOG_PREFIX} instrumentation sweep failed: #{e.message}"
          end
        end

        # Whether this instrumentation is installable right now.
        def ready_to_install?(instrumentation)
          return false if instrumentation.installed?

          instrumentation.present? && instrumentation.enabled? && instrumentation.compatible?
        rescue StandardError, ScriptError
          false
        end

        # The instrumentation instances this process should install: those named by
        # +enabled_names+, or every registered instrumentation when +enabled_names+
        # is empty.
        def relevant_instrumentations(enabled_names)
          registry = ::OpenTelemetry::Instrumentation.registry
          if enabled_names.empty?
            registry_instrumentation_classes.map(&:instance)
          else
            enabled_names.filter_map { |name| registry.lookup(name) }
          end
        rescue StandardError
          []
        end

        # All instrumentation classes registered in the OpenTelemetry registry. The
        # registry only exposes lookup/install publicly, so enumerate its internal
        # collection to derive the supported set.
        def registry_instrumentation_classes
          registry = ::OpenTelemetry::Instrumentation.registry
          registry.instance_variable_get(:@instrumentation) || []
        rescue StandardError
          []
        end

        # Builds and caches a hash mapping alias names (snake_case, no prefix) to
        # canonical instrumentation names.
        def registry_lookup
          @registry_lookup ||= registry_instrumentation_classes.each_with_object({}) do |klass, lookup|
            canonical = klass.instance.name
            registry_aliases_for(canonical).each do |alias_name|
              lookup[alias_name] ||= canonical
            end
          rescue StandardError
            next
          end
        end

        # All snake_case alias strings for a fully-qualified instrumentation name,
        # e.g. "OpenTelemetry::Instrumentation::Net::HTTP" => ["net_http", ...].
        def registry_aliases_for(instrumentation_name)
          suffix = instrumentation_name.delete_prefix('OpenTelemetry::Instrumentation::')
          segment_variants = suffix.split('::').map do |segment|
            [snake_case(segment), segment.downcase].uniq
          end

          segment_variants.reduce(['']) do |aliases, variants|
            aliases.flat_map do |prefix|
              variants.map { |variant| prefix.empty? ? variant : "#{prefix}_#{variant}" }
            end
          end
        end

        def snake_case(value)
          value
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .tr('-', '_')
            .downcase
        end
      end
    end
  end
end
