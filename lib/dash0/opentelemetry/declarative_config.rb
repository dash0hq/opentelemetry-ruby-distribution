# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'dash0/opentelemetry/declarative_config/env_substitution'
require 'dash0/opentelemetry/declarative_config/logs'
require 'dash0/opentelemetry/declarative_config/metrics'
require 'dash0/opentelemetry/declarative_config/metric_views'

module Dash0
  module OpenTelemetry
    # Wraps opentelemetry-config to support declarative configuration it does
    # not support yet. Each gap is filled only when upstream leaves it empty, so
    # the copies here become unused as upstream releases them, and can be deleted.
    module DeclarativeConfig
      module_function

      # Creates the SDK components described by a configuration model, adding the
      # providers opentelemetry-config does not build yet.
      #
      # @param model [OpenTelemetry::Config::Model::OpenTelemetryConfiguration]
      # @return [OpenTelemetry::Config::RubySDK]
      def create(model)
        sdk = ::OpenTelemetry::Config.create(model)
        return sdk if sdk.equal?(::OpenTelemetry::Config::NOOP_SDK)

        sdk.meter_provider ||= Metrics.build_meter_provider(model.meter_provider, sdk.resource)
        sdk.logger_provider ||= Logs.build_logger_provider(model.logger_provider, sdk.resource)
        sdk
      end

      # Installs the SDK components as the global OpenTelemetry state, including
      # the providers opentelemetry-config does not install yet.
      #
      # @param sdk [OpenTelemetry::Config::RubySDK]
      # @return [OpenTelemetry::Config::RubySDK] the same SDK handle
      def install(sdk)
        return sdk if sdk.equal?(::OpenTelemetry::Config::NOOP_SDK)

        ::OpenTelemetry::Config.install(sdk)
        install_meter_provider(sdk.meter_provider) if sdk.meter_provider
        ::OpenTelemetry.logger_provider = sdk.logger_provider if sdk.logger_provider
        sdk
      end

      # Installs the meter provider as the global and restarts its periodic
      # readers in forked child processes. Safe to repeat.
      def install_meter_provider(provider)
        ::OpenTelemetry.meter_provider = provider
        ::OpenTelemetry::SDK::Metrics::ForkHooks.attach!
      end

      # Returns exporter headers from +headers+, or from +headers_list+ when
      # +headers+ is empty.
      def headers_to_hash(cfg)
        headers = {}

        Array(cfg.headers).each do |pair|
          headers[pair.name] = pair.value if pair&.name
        end

        if headers.empty? && cfg.headers_list.is_a?(String)
          cfg.headers_list.split(',').each do |entry|
            key, value = entry.strip.split('=', 2)
            headers[key] = value if key && value
          end
        end

        headers
      end
    end
  end
end
