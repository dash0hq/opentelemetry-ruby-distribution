# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    module Resource
      # Resource detector that identifies this distribution via the
      # `telemetry.distro.*` resource attributes.
      #
      # `OpenTelemetry::SDK` must be loaded before this is called.
      module Distribution
        # Value of the `telemetry.distro.name` resource attribute.
        NAME = 'dash0-ruby'

        module_function

        def detect
          ::OpenTelemetry::SDK::Resources::Resource.create(
            'telemetry.distro.name' => NAME,
            'telemetry.distro.version' => Dash0::OpenTelemetry::VERSION
          )
        end
      end
    end
  end
end
