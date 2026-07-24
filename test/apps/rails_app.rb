# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

# Minimal Rails app for the default-stack integration smoke. The distribution is
# preloaded via `ruby -r dash0-opentelemetry`, so Rails is required *after*
# startup here — exercising the TracePoint sweep against the real Rails/Rack boot
# (the load-ordering scenario a plain `net/http` require does not reproduce).
#
# API-only (no ActiveRecord) and dispatched in-process via Rack, so there is no
# server, port, or database.

require 'logger' # Rails 7.x expects Logger to be required before it uses it
require 'rails'
require 'action_controller/railtie'
require 'rack/mock'

class RailsSmokeApp < Rails::Application
  config.eager_load = false
  config.consider_all_requests_local = true
  config.secret_key_base = 'integration-test-secret'
  config.logger = Logger.new(File::NULL)
  config.hosts.clear # allow the Rack::MockRequest host
  routes.append do
    get '/hello', to: 'hello#index'
  end
end

class HelloController < ActionController::API
  def index
    render json: { ok: true }
  end
end

Rails.application.initialize!

status, = RailsSmokeApp.call(Rack::MockRequest.env_for('/hello'))
warn "rails-smoke: GET /hello -> #{status}"
