# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    module DeclarativeConfig
      class ResourceDetectorsTest < Minitest::Test
        include TestHelpers

        TRACER_PROVIDER_YAML = <<~YAML
          tracer_provider:
            processors:
              - simple:
                  exporter:
                    console: {}
        YAML

        def test_dash0_distribution_detector_adds_distro_attributes
          attributes = boot_resource(<<~YAML)
            resource:
              detection/development:
                detectors:
                  - dash0_distribution: {}
                  - dash0_kubernetes: {}
          YAML

          assert_equal 'dash0-ruby', attributes['telemetry.distro.name']
          assert_equal Dash0::OpenTelemetry::VERSION, attributes['telemetry.distro.version']
        end

        def test_dash0_detectors_apply_only_when_named
          attributes = boot_resource('resource: {}')

          assert_nil attributes['telemetry.distro.name']
        end

        def test_service_name_fallback_replaces_the_default_service_name
          attributes = boot_resource(<<~YAML, 'OTEL_SERVICE_NAME' => nil)
            resource:
              attributes:
                - name: service.name
                  value: ${OTEL_SERVICE_NAME:-unknown_service}
              detection/development:
                detectors:
                  - dash0_service_name: {}
          YAML

          assert_equal 'my_worker', attributes['service.name']
        end

        def test_service_name_fallback_keeps_a_service_name_set_by_the_file
          attributes = boot_resource(<<~YAML)
            resource:
              attributes:
                - name: service.name
                  value: from-file
              detection/development:
                detectors:
                  - dash0_service_name: {}
          YAML

          assert_equal 'from-file', attributes['service.name']
        end

        def test_service_name_fallback_uses_otel_service_name
          attributes = boot_resource(<<~YAML, 'OTEL_SERVICE_NAME' => 'from-env')
            resource:
              detection/development:
                detectors:
                  - dash0_service_name: {}
          YAML

          assert_equal 'from-env', attributes['service.name']
        end

        def test_service_name_fallback_applies_only_when_named
          attributes = boot_resource('resource: {}', 'OTEL_SERVICE_NAME' => nil)

          assert_equal 'unknown_service', attributes['service.name']
        end

        def test_install_skips_an_unsupported_opentelemetry_config
          result = run_in_subprocess do
            require 'stringio'
            require 'dash0/opentelemetry'
            Dash0::OpenTelemetry::SdkConfiguration.require_sdk_gems
            require 'opentelemetry-config'
            ::OpenTelemetry::Config.singleton_class.send(:remove_method, :run_detector)

            $stderr = StringIO.new
            ResourceDetectors.install
            {
              patched: ::OpenTelemetry::Config.singleton_class.ancestors.include?(ResourceDetectors::ConfigPatch),
              stderr: $stderr.string
            }
          end

          refute result[:error], result[:error]
          refute result[:patched]
          assert_includes result[:stderr], 'not supported by the Dash0 resource detectors'
        end

        private

        # Boots from a configuration file with the given resource section and
        # returns the tracer provider's resource attributes.
        def boot_resource(resource_yaml, env = {})
          path = write_config_file("file_format: \"1.0\"\n#{resource_yaml}\n#{TRACER_PROVIDER_YAML}")

          result = run_in_subprocess(env.merge('OTEL_CONFIG_FILE' => path)) do
            require 'tmpdir'
            # Give the service name fallback a predictable program name and no project root.
            Dir.chdir(Dir.mktmpdir)
            $PROGRAM_NAME = '/app/my_worker.rb'
            require 'dash0-opentelemetry'
            ::OpenTelemetry.tracer_provider.resource.attribute_enumerator.to_h
          end

          refute result.is_a?(Hash) && result[:error], result.is_a?(Hash) && result[:error]
          result
        end
      end
    end
  end
end
