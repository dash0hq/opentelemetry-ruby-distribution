# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'open3'
require_relative '../collector/fake_collector'

# Helpers for integration tests that run a sample app in a separate process with
# the distribution preloaded via `ruby -r dash0-opentelemetry` (the same
# mechanism the operator uses via RUBYOPT), pointed at an in-process mock
# collector.
module IntegrationHelper
  REPO_ROOT = File.expand_path('../..', __dir__)
  APP_DIR = File.join(REPO_ROOT, 'test', 'apps')

  # Starts a mock collector, yields it, and always stops it.
  def with_collector
    collector = FakeCollector.new.start
    yield collector
  ensure
    collector&.stop
  end

  # Runs a sample app with the distribution preloaded. `preload:` mirrors the
  # operator's RUBYOPT injection; set it to false for apps that require the
  # distribution themselves. Returns [stdout, stderr, Process::Status].
  def run_distro_app(app, env: {}, preload: true)
    args = ['bundle', 'exec', 'ruby', '-I', 'lib']
    args += ['-r', 'dash0-opentelemetry'] if preload
    args << File.join(APP_DIR, app)
    Open3.capture3(default_env.merge(env), *args, chdir: REPO_ROOT)
  end

  def default_env
    {
      'DASH0_DEBUG' => 'false',
      # Speed up export in case the at-exit flush is not the only path exercised.
      'OTEL_BSP_SCHEDULE_DELAY' => '50',
      'OTEL_BLRP_SCHEDULE_DELAY' => '50',
      'OTEL_METRIC_EXPORT_INTERVAL' => '200'
    }
  end

  # Polls the block until it returns truthy or the timeout elapses.
  def wait_until(timeout: 15, interval: 0.05)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      raise 'timed out waiting for expected telemetry' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep interval
    end
  end
end
