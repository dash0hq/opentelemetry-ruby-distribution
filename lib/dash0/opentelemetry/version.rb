# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    VERSION = '0.1.0'

    # Lowest Ruby version the distribution supports. Kept here (in a file that
    # must stay parse-safe on older Rubies) so the requirable entry point can
    # gate on it before requiring anything that uses newer syntax.
    MINIMUM_RUBY_VERSION = '3.3.0'
  end
end
