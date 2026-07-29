# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# A plain app with no OpenTelemetry references, used by the fail-open smoke check.
# The distribution is preloaded with an unusable gem bundle, so it stands down and
# never loads the SDK; this app must still run to completion — the injector must
# never crash the host it is injected into.

puts 'PLAIN_APP_DONE'
