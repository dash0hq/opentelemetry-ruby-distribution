# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    module Resource
      class ServiceNameFallbackTest < Minitest::Test
        include TestHelpers

        # The detector's only public method is `detect`; the helpers below are
        # internal and exercised via `send`.

        def test_derives_service_name_from_program_name
          with_env(clear_service_name_env) do
            assert_equal 'my_app', ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb')
            assert_equal 'rails', ServiceNameFallback.send(:fallback_service_name, '/usr/bin/rails')
          end
        end

        def test_returns_nil_when_program_name_unusable
          with_env(clear_service_name_env) do
            assert_nil ServiceNameFallback.send(:fallback_service_name, '')
            assert_nil ServiceNameFallback.send(:fallback_service_name, nil)
          end
        end

        def test_opted_out_disables_fallback
          with_env(clear_service_name_env.merge('DASH0_AUTOMATIC_SERVICE_NAME' => 'false')) do
            assert_nil ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb')
          end
        end

        def test_otel_service_name_disables_fallback
          with_env(clear_service_name_env.merge('OTEL_SERVICE_NAME' => 'explicit')) do
            assert_nil ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb')
          end
        end

        def test_service_name_in_resource_attributes_disables_fallback
          with_env(clear_service_name_env.merge('OTEL_RESOURCE_ATTRIBUTES' => 'service.name=explicit,foo=bar')) do
            assert_nil ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb')
          end
        end

        def test_service_name_in_resource_attributes_strips_quotes
          with_env(clear_service_name_env.merge('OTEL_RESOURCE_ATTRIBUTES' => 'service.name="explicit"')) do
            assert ServiceNameFallback.send(:service_name_in_resource_attributes?)
          end
        end

        def test_empty_service_name_in_resource_attributes_does_not_disable_fallback
          with_env(clear_service_name_env.merge('OTEL_RESOURCE_ATTRIBUTES' => 'service.name=,foo=bar')) do
            assert_equal 'my_app', ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb')
          end
        end

        private

        def clear_service_name_env
          {
            'DASH0_AUTOMATIC_SERVICE_NAME' => nil,
            'OTEL_SERVICE_NAME' => nil,
            'OTEL_RESOURCE_ATTRIBUTES' => nil
          }
        end
      end
    end
  end
end
