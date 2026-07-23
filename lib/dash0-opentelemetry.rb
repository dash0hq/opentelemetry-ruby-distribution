# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# Requirable entry point for the Dash0 OpenTelemetry distribution for Ruby.
#
# This is the file the Dash0 operator/injector points `RUBYOPT="-r ..."` at.
# Requiring it boots the distribution as a side effect.

require 'dash0/opentelemetry'

Dash0::OpenTelemetry.boot!
