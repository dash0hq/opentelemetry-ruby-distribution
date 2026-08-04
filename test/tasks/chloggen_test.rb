# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'chloggen'

class ChloggenTest < Minitest::Test
  def test_parse_fragment_returns_the_relevant_fields
    fragment = Chloggen.parse_fragment(<<~YAML)
      change_type: added
      note: Something new.
      issues: [8]
    YAML

    assert_equal({ 'change_type' => 'added', 'note' => 'Something new.', 'issues' => [8] }, fragment)
  end

  def test_parse_fragment_rejects_a_missing_change_type
    error = assert_raises(Chloggen::FragmentError) do
      Chloggen.parse_fragment("note: Something new.\nissues: [8]\n")
    end
    assert_match(/change_type is required/, error.message)
  end

  def test_parse_fragment_rejects_an_unknown_change_type
    error = assert_raises(Chloggen::FragmentError) do
      Chloggen.parse_fragment("change_type: nope\nnote: Something new.\nissues: [8]\n")
    end
    assert_match(/change_type must be one of/, error.message)
  end

  def test_parse_fragment_rejects_a_missing_note
    error = assert_raises(Chloggen::FragmentError) do
      Chloggen.parse_fragment("change_type: added\nissues: [8]\n")
    end
    assert_match(/note is required/, error.message)
  end

  def test_parse_fragment_rejects_missing_or_empty_issues
    error = assert_raises(Chloggen::FragmentError) do
      Chloggen.parse_fragment("change_type: added\nnote: Something new.\nissues: []\n")
    end
    assert_match(/issues must be a non-empty array/, error.message)
  end

  def test_parse_fragment_reports_every_problem_at_once
    error = assert_raises(Chloggen::FragmentError) { Chloggen.parse_fragment('{}') }
    assert_match(/change_type is required/, error.message)
    assert_match(/note is required/, error.message)
    assert_match(/issues must be a non-empty array/, error.message)
  end

  def test_merge_appends_to_an_existing_section
    changelog = <<~CHANGELOG
      # Changelog

      ## [Unreleased]

      ### Added

      - Existing entry.
    CHANGELOG

    fragment = { 'change_type' => 'added', 'note' => 'New entry.', 'issues' => [8] }

    assert_equal(<<~CHANGELOG, Chloggen.merge(changelog, [fragment]))
      # Changelog

      ## [Unreleased]

      ### Added

      - Existing entry.
      - New entry. (#8)

    CHANGELOG
  end

  def test_merge_creates_sections_in_keep_a_changelog_order
    changelog = "# Changelog\n\n## [Unreleased]\n"
    fragments = [
      { 'change_type' => 'fixed', 'note' => 'A fix.', 'issues' => [2] },
      { 'change_type' => 'added', 'note' => 'A feature.', 'issues' => [1] }
    ]

    assert_equal(<<~CHANGELOG, Chloggen.merge(changelog, fragments))
      # Changelog

      ## [Unreleased]

      ### Added

      - A feature. (#1)

      ### Fixed

      - A fix. (#2)

    CHANGELOG
  end

  def test_merge_preserves_content_after_unreleased
    changelog = <<~CHANGELOG
      # Changelog

      ## [Unreleased]

      ## [0.1.0] - 2026-01-01

      ### Added

      - First release.
    CHANGELOG

    fragment = { 'change_type' => 'added', 'note' => 'New entry.', 'issues' => [8] }
    merged = Chloggen.merge(changelog, [fragment])

    assert_includes merged, "## [0.1.0] - 2026-01-01\n\n### Added\n\n- First release."
    assert_includes merged, '- New entry. (#8)'
  end

  def test_merge_raises_without_an_unreleased_section
    assert_raises(Chloggen::FragmentError) do
      Chloggen.merge("# Changelog\n", [{ 'change_type' => 'added', 'note' => 'x', 'issues' => [1] }])
    end
  end

  def test_bullet_for_joins_multiple_issues
    fragment = { 'change_type' => 'added', 'note' => 'A feature.', 'issues' => [1, 2] }

    assert_equal '- A feature. (#1, #2)', Chloggen.bullet_for(fragment)
  end

  def test_shipped_changes_includes_the_distributions_own_code
    assert_equal ['lib/dash0/opentelemetry/boot.rb'],
                 Chloggen.shipped_changes(['lib/dash0/opentelemetry/boot.rb', 'test/dash0/opentelemetry/boot_test.rb'])
  end

  def test_shipped_changes_includes_the_gemspecs_shipped_dependency_constraints
    assert_equal ['dash0-opentelemetry.gemspec'], Chloggen.shipped_changes(['dash0-opentelemetry.gemspec'])
  end

  def test_shipped_changes_includes_the_packaging_lockfile_for_transitive_bumps
    assert_equal ['packaging/Gemfile.lock'], Chloggen.shipped_changes(['packaging/Gemfile.lock'])
  end

  def test_shipped_changes_excludes_dev_and_test_dependency_updates
    assert_empty Chloggen.shipped_changes(%w[Gemfile Gemfile.lock])
  end

  def test_shipped_changes_excludes_infrastructure_tests_and_docs
    changed = %w[
      .github/workflows/ci.yml
      .github/dependabot.yml
      Rakefile
      tasks/chloggen.rake
      test/test_helper.rb
      packaging/Dockerfile
      packaging/README.md
      README.md
    ]

    assert_empty Chloggen.shipped_changes(changed)
  end

  def test_shipped_changes_does_not_match_paths_that_merely_share_a_prefix
    assert_empty Chloggen.shipped_changes(%w[library/notes.md dash0-opentelemetry.gemspec.bak])
  end

  def test_fragment_changes_finds_added_fragments
    assert_equal ['.chloggen/my-change.yaml'],
                 Chloggen.fragment_changes(['lib/dash0/opentelemetry.rb', '.chloggen/my-change.yaml'])
  end

  def test_fragment_changes_ignores_the_template_and_the_readme
    assert_empty Chloggen.fragment_changes(['.chloggen/TEMPLATE.yaml', '.chloggen/README.md'])
  end
end
