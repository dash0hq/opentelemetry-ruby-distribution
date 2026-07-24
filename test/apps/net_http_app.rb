# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# Sample app that exercises zero-code auto-instrumentation. `net/http` is required
# here — i.e. *after* the distribution was preloaded — so this also proves the
# TracePoint sweep instruments libraries loaded after startup. The GET target is
# the mock collector (passed via TARGET_URL), which returns 200 for any path.

require 'net/http'
require 'uri'

Net::HTTP.get(URI(ENV.fetch('TARGET_URL')))
