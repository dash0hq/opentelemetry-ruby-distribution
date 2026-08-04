# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'open3'
require 'tmpdir'

# Exercises the `chloggen:required` task end to end, because its exit code is
# what CI gates pull requests on (see .github/workflows/ci.yml).
class ChloggenRequiredTaskTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  # Resolved from the bundle rather than shelling out to `bundle exec rake`, so
  # the test does not depend on a `rake` executable being on PATH.
  RAKE = Gem.bin_path('rake', 'rake')

  def test_passes_for_dependency_updates_that_are_not_shipped
    output, status = run_task(%w[Gemfile Gemfile.lock .github/workflows/ci.yml])

    assert_predicate status, :success?, output
    assert_match(/no changelog fragment needed/, output)
  end

  def test_fails_for_a_shipped_dependency_bump_without_a_fragment
    output, status = run_task(%w[dash0-opentelemetry.gemspec packaging/Gemfile.lock])

    refute_predicate status, :success?, output
    assert_match(%r{dash0-opentelemetry\.gemspec, packaging/Gemfile\.lock}, output)
    assert_match(%r{adds no\s+\.chloggen/\*\.yaml fragment}, output)
  end

  def test_passes_for_a_shipped_dependency_bump_with_a_fragment
    output, status = run_task(%w[packaging/Gemfile.lock .chloggen/bump-otel.yaml])

    assert_predicate status, :success?, output
    assert_match(%r{Found changelog fragment\(s\):\s+\.chloggen/bump-otel\.yaml}, output)
  end

  def test_fails_when_only_the_template_is_touched_alongside_a_shipped_change
    output, status = run_task(%w[lib/dash0/opentelemetry.rb .chloggen/TEMPLATE.yaml])

    refute_predicate status, :success?, output
  end

  private

  def run_task(changed_files)
    Dir.mktmpdir do |dir|
      list = File.join(dir, 'changed-files.txt')
      File.write(list, "#{changed_files.join("\n")}\n")
      Open3.capture2e({ 'GITHUB_ACTIONS' => nil }, RbConfig.ruby, RAKE, "chloggen:required[#{list}]", chdir: ROOT)
    end
  end
end
