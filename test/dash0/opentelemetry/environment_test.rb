# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    class EnvironmentTest < Minitest::Test
      include TestHelpers

      def test_opted_in_is_true_only_for_true
        with_env('DASH0_X' => 'true') { assert Environment.opted_in?('DASH0_X') }
        with_env('DASH0_X' => 'TRUE') { assert Environment.opted_in?('DASH0_X') }
        with_env('DASH0_X' => '  true ') { assert Environment.opted_in?('DASH0_X') }
        with_env('DASH0_X' => 'false') { refute Environment.opted_in?('DASH0_X') }
        with_env('DASH0_X' => nil) { refute Environment.opted_in?('DASH0_X') }
      end

      def test_opted_out_is_true_only_for_false
        with_env('DASH0_X' => 'false') { assert Environment.opted_out?('DASH0_X') }
        with_env('DASH0_X' => 'FALSE') { assert Environment.opted_out?('DASH0_X') }
        with_env('DASH0_X' => 'true') { refute Environment.opted_out?('DASH0_X') }
        with_env('DASH0_X' => nil) { refute Environment.opted_out?('DASH0_X') }
      end

      def test_present
        with_env('DASH0_X' => 'value') { assert Environment.present?('DASH0_X') }
        with_env('DASH0_X' => '   ') { refute Environment.present?('DASH0_X') }
        with_env('DASH0_X' => nil) { refute Environment.present?('DASH0_X') }
      end

      def test_set_default_only_sets_when_absent_or_empty
        with_env('DASH0_X' => nil) do
          Environment.set_default('DASH0_X', 'default')

          assert_equal 'default', ENV.fetch('DASH0_X', nil)
        end

        with_env('DASH0_X' => 'existing') do
          Environment.set_default('DASH0_X', 'default')

          assert_equal 'existing', ENV.fetch('DASH0_X', nil)
        end

        with_env('DASH0_X' => '  ') do
          Environment.set_default('DASH0_X', 'default')

          assert_equal 'default', ENV.fetch('DASH0_X', nil)
        end
      end

      def test_integer_parsing_with_default
        with_env('DASH0_N' => '42') { assert_equal 42, Environment.integer('DASH0_N', 7) }
        with_env('DASH0_N' => 'nope') { assert_equal 7, Environment.integer('DASH0_N', 7) }
        with_env('DASH0_N' => nil) { assert_equal 7, Environment.integer('DASH0_N', 7) }
      end

      def test_debug
        with_env('DASH0_DEBUG' => 'true') { assert_predicate Environment, :debug? }
        with_env('DASH0_DEBUG' => nil) { refute_predicate Environment, :debug? }
      end
    end
  end
end
