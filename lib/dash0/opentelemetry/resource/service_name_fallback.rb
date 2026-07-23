# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    module Resource
      # Resource detector that provides a fallback `service.name` when none has
      # been configured. We derive the name from the program's entry point.
      #
      # The fallback is skipped when a service name is already configured via
      # `OTEL_SERVICE_NAME` or a `service.name` in `OTEL_RESOURCE_ATTRIBUTES`, or
      # when opted out with `DASH0_AUTOMATIC_SERVICE_NAME=false`.
      #
      # `OpenTelemetry::SDK` must be loaded before `detect` is called.
      module ServiceNameFallback
        AUTOMATIC_SERVICE_NAME_ENV = 'DASH0_AUTOMATIC_SERVICE_NAME'
        SERVICE_NAME_KEY = 'service.name'

        extend self

        # The detector interface: the only public method.
        def detect
          attributes = {}
          name = fallback_service_name
          attributes[SERVICE_NAME_KEY] = name if name
          ::OpenTelemetry::SDK::Resources::Resource.create(attributes)
        end

        private

        # @return [String, nil] the derived service name, or nil when a name is
        #   already configured, the fallback is opted out, or no name can be derived.
        def fallback_service_name(program_name = $PROGRAM_NAME)
          return nil if service_name_configured?

          derive_from_program_name(program_name)
        end

        def service_name_configured?
          opted_out? || otel_service_name_set? || service_name_in_resource_attributes?
        end

        def opted_out?
          Environment.opted_out?(AUTOMATIC_SERVICE_NAME_ENV)
        end

        def otel_service_name_set?
          Environment.present?('OTEL_SERVICE_NAME')
        end

        # Parses OTEL_RESOURCE_ATTRIBUTES the same way the upstream env detector
        # does, stripping surrounding quotes, to see if a non-empty service.name
        # is present.
        def service_name_in_resource_attributes?
          raw = ENV.fetch('OTEL_RESOURCE_ATTRIBUTES', nil)
          return false if raw.nil? || raw.strip.empty?

          raw.split(',').any? do |pair|
            key, value = pair.split('=', 2)
            next false unless value && key.strip == SERVICE_NAME_KEY

            !value.strip.gsub(/\A"|"\z/, '').strip.empty?
          end
        end

        def derive_from_program_name(program_name)
          return nil if program_name.nil?

          name = File.basename(program_name.to_s).delete_suffix('.rb')
          name.empty? ? nil : name
        end
      end
    end
  end
end
