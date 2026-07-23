# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require 'minitest/autorun'

module TestHelpers
  # Temporarily sets environment variables for the duration of the block,
  # restoring the previous values (including "was unset") afterwards.
  def with_env(vars)
    previous = {}
    vars.each do |key, value|
      previous[key] = ENV.key?(key) ? ENV[key] : :__unset__
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    previous.each do |key, value|
      value == :__unset__ ? ENV.delete(key) : ENV[key] = value
    end
  end

  # Runs the given block in a forked subprocess with the supplied environment,
  # returning whatever (marshalable) value the block produced. Booting the SDK
  # mutates global process state, so tests that exercise a full boot run in a
  # clean child process.
  def run_in_subprocess(env_vars = {})
    skip 'fork is not available on this platform' unless Process.respond_to?(:fork)

    reader, writer = IO.pipe
    pid = fork do
      reader.close
      SimpleCov.command_name "subprocess-#{Process.pid}" if defined?(SimpleCov) && SimpleCov.running
      env_vars.each { |key, value| ENV[key] = value }

      result =
        begin
          yield
        rescue StandardError => e
          { error: e.message, backtrace: e.backtrace }
        end

      writer.write(Marshal.dump(result))
      writer.close
      if defined?(SimpleCov) && SimpleCov.running
        SimpleCov::ResultMerger.store_result(SimpleCov::Result.new(Coverage.result))
      end
      exit!(0)
    end

    writer.close
    data = reader.read
    reader.close
    Process.wait(pid)

    # rubocop:disable Security/MarshalLoad
    Marshal.load(data)
    # rubocop:enable Security/MarshalLoad
  end
end
