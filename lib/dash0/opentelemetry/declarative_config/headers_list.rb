# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'uri'

module Dash0
  module OpenTelemetry
    module DeclarativeConfig
      # Percent-decodes the exporter headers that a configuration file gives in
      # +headers_list+, which uses the same W3C Baggage format as
      # OTEL_EXPORTER_OTLP_HEADERS. Values from the +headers+ struct are literal
      # and stay as written.
      #
      # opentelemetry-config does not decode +headers_list+, so this patches the
      # parser its trace and log exporters share. The patch is skipped once the
      # installed opentelemetry-config decodes on its own.
      module HeadersList
        # Prepended to the singleton class of opentelemetry-config's Trace module.
        module TracePatch
          def headers_to_hash(cfg)
            headers = super
            return headers if HeadersList.struct_headers?(cfg)

            HeadersList.decode_all(headers)
          end
        end

        PROBE = Struct.new(:headers, :headers_list).new(nil, 'k=a%20b')
        private_constant :PROBE

        module_function

        # Patches opentelemetry-config to decode +headers_list+. Safe to repeat.
        def install
          trace = trace_module
          return unless trace
          return unless trace.headers_to_hash(PROBE)['k'] == 'a%20b'

          trace.singleton_class.prepend(TracePatch)
        end

        # Returns a copy of +headers+ with every name and value percent-decoded.
        #
        # @param headers [Hash{String => String}]
        # @return [Hash{String => String}]
        def decode_all(headers)
          headers.to_h { |name, value| [decode(name), decode(value)] }
        end

        # Percent-decodes +value+, or returns it unchanged when it is not valid
        # percent-encoding.
        def decode(value)
          URI.decode_uri_component(value)
        rescue ArgumentError
          value
        end

        # Whether +cfg+ sets the +headers+ struct, which takes precedence over
        # +headers_list+.
        def struct_headers?(cfg)
          Array(cfg.headers).any? { |pair| pair&.name }
        end

        # opentelemetry-config's private Trace module, or nil when it has no
        # headers_to_hash to patch.
        def trace_module
          return unless ::OpenTelemetry::Config.const_defined?(:Trace, false)

          trace = ::OpenTelemetry::Config.const_get(:Trace, false)
          trace if trace.respond_to?(:headers_to_hash)
        end
      end
    end
  end
end
