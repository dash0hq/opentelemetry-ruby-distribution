# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'

module Dash0
  # The gem is installed outside the application bundle, so on `gem install`
  # its runtime dependencies resolve from the gemspec alone. Each is pinned to
  # the minor version the packaging bundle is tested with.
  class GemspecTest < Minitest::Test
    GEMSPEC = File.expand_path('../../dash0-opentelemetry.gemspec', __dir__)
    PATCH_LEVEL_TWIDDLE = /\A~> \d+\.\d+\.\d+\z/

    def test_every_runtime_dependency_is_pinned_to_one_minor_version
      loose = Gem::Specification.load(GEMSPEC).runtime_dependencies.reject do |dependency|
        dependency.requirement.to_s.match?(PATCH_LEVEL_TWIDDLE)
      end

      assert_empty loose.map { |dependency| "#{dependency.name} #{dependency.requirement}" },
                   "Pin each runtime dependency as '~> X.Y.Z'. Dependabot widens gemspec pins to ranges; " \
                   'restore the pin to the version in packaging/Gemfile.lock'
    end
  end
end
