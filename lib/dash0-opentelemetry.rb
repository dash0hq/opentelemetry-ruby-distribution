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

# When the operator/injector preloads this file via `RUBYOPT="-r <abs path>"`,
# Ruby loads it by absolute path without activating the gem, and no Bundler is
# involved, so this gem's own `lib` is not on the load path yet. Put it there so
# `require 'dash0/...'` resolves. (Under Bundler this is a harmless no-op.)
dash0_lib_dir = __dir__
$LOAD_PATH.unshift(dash0_lib_dir) unless $LOAD_PATH.include?(dash0_lib_dir)

require 'dash0/opentelemetry/version'

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(Dash0::OpenTelemetry::MINIMUM_RUBY_VERSION)
  warn "[Dash0 OpenTelemetry Distribution] Ruby #{RUBY_VERSION} is not supported " \
       "(requires >= #{Dash0::OpenTelemetry::MINIMUM_RUBY_VERSION}). " \
       'OpenTelemetry data will not be sent to Dash0.'
  return
end

# This rescue ensures we fail open if there is an issue loading our library.
# Unlikely but not impossible: a missing/corrupt distribution file, or a
# SyntaxError in our lib.
begin
  require 'dash0/opentelemetry'
  Dash0::OpenTelemetry.boot!
rescue StandardError, ScriptError => e
  warn "[Dash0 OpenTelemetry Distribution] Initialization failed: #{e.message}. " \
       'OpenTelemetry data will not be sent to Dash0.'
end
