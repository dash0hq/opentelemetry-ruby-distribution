# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    module DeclarativeConfig
      # Lets a configuration file name the Dash0 resource detectors, e.g.
      #
      #   resource:
      #     detection/development:
      #       detectors:
      #         - dash0_distribution: {}
      #         - dash0_kubernetes: {}
      #         - dash0_service_name: {}
      #
      # opentelemetry-config has no extension point for detectors and warns about
      # names it does not know, so this patches its private resource builders.
      # The patch is skipped if those builders change.
      module ResourceDetectors
        SERVICE_NAME_DETECTOR = 'dash0_service_name'
        DEFAULT_SERVICE_NAME = 'unknown_service'
        DETECTORS = {
          'dash0_distribution' => Resource::Distribution,
          'dash0_kubernetes' => Resource::KubernetesPod
        }.freeze

        # Prepended to the singleton class of OpenTelemetry::Config.
        module ConfigPatch
          private

          # The service name fallback runs in build_resource, after the file's
          # own attributes are known.
          def run_detector(name)
            return DETECTORS.fetch(name).detect if DETECTORS.key?(name)
            return ::OpenTelemetry::SDK::Resources::Resource.create({}) if name == SERVICE_NAME_DETECTOR

            super
          end

          # Applies the service name fallback when the file names it and does not
          # set a service name of its own.
          def build_resource(resource_cfg)
            resource = super
            return resource unless ResourceDetectors.service_name_requested?(resource_cfg)

            service_name = resource.attribute_enumerator.to_h['service.name']
            return resource unless service_name.nil? || service_name == DEFAULT_SERVICE_NAME

            resource.merge(Resource::ServiceNameFallback.detect(declarative: true))
          end
        end

        module_function

        # Patches opentelemetry-config to run the Dash0 detectors. Safe to repeat.
        def install
          config = ::OpenTelemetry::Config.singleton_class
          unless %i[run_detector build_resource].all? { |name| config.private_method_defined?(name) }
            Dash0::OpenTelemetry.log_error(
              'The installed opentelemetry-config is not supported by the Dash0 resource detectors. ' \
              'Configuration files cannot use dash0_distribution, dash0_kubernetes, or dash0_service_name.'
            )
            return
          end

          config.prepend(ConfigPatch)
        end

        # Whether the file names the service name fallback detector.
        def service_name_requested?(resource_cfg)
          Array(resource_cfg&.detection_development&.detectors).any? do |detector|
            detector&.additional_properties&.key?(SERVICE_NAME_DETECTOR)
          end
        end
      end
    end
  end
end
