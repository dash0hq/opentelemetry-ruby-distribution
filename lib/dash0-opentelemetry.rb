# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# Requirable entry point for the Dash0 OpenTelemetry distribution for Ruby.
#
# This is the file the Dash0 operator/injector points `RUBYOPT="-r ..."` at.
# Requiring it boots the distribution as a side effect.
#
# IMPORTANT: the injector preloads this file into whatever Ruby the target app
# runs and performs no Ruby-version detection of its own. So this file must stay
# syntactically conservative (parse-safe on older Rubies) and check the runtime
# version BEFORE requiring any of the distribution's other files, which are free
# to use modern syntax. On an unsupported Ruby we stand down cleanly rather than
# crash the host application.

require 'dash0/opentelemetry/version'

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(Dash0::OpenTelemetry::MINIMUM_RUBY_VERSION)
  warn "[Dash0 OpenTelemetry Distribution] Ruby #{RUBY_VERSION} is not supported " \
       "(requires >= #{Dash0::OpenTelemetry::MINIMUM_RUBY_VERSION}). " \
       'OpenTelemetry data will not be sent to Dash0.'
  return
end

require 'dash0/opentelemetry'

Dash0::OpenTelemetry.boot!
