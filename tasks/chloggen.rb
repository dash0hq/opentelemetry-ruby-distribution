# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'yaml'

# Parses and merges .chloggen changelog fragments (see .chloggen/README.md).
# Kept dependency-free of Rake so it can be required directly from tests.
module Chloggen
  CHANGE_TYPES = %w[added changed deprecated removed fixed security].freeze

  SECTION_TITLES = {
    'added' => 'Added',
    'changed' => 'Changed',
    'deprecated' => 'Deprecated',
    'removed' => 'Removed',
    'fixed' => 'Fixed',
    'security' => 'Security'
  }.freeze

  UNRELEASED_HEADER = '## [Unreleased]'

  class FragmentError < StandardError; end

  # Parses and validates a single fragment's YAML text, returning
  # { 'change_type' => ..., 'note' => ..., 'issues' => [...] }.
  # Raises FragmentError describing every problem found.
  def self.parse_fragment(yaml_text)
    data = YAML.safe_load(yaml_text) || {}
    errors = []

    change_type = data['change_type'].to_s
    if change_type.empty?
      errors << 'change_type is required'
    elsif !CHANGE_TYPES.include?(change_type)
      errors << "change_type must be one of #{CHANGE_TYPES.join(', ')} (got #{change_type.inspect})"
    end

    note = data['note'].to_s
    errors << 'note is required' if note.strip.empty?

    issues = data['issues']
    errors << 'issues must be a non-empty array of issue/PR numbers' unless issues.is_a?(Array) && !issues.empty?

    raise FragmentError, errors.join('; ') unless errors.empty?

    { 'change_type' => change_type, 'note' => note, 'issues' => issues }
  end

  def self.bullet_for(fragment)
    issue_refs = fragment.fetch('issues').map { |issue| "##{issue}" }.join(', ')
    "- #{fragment.fetch('note')} (#{issue_refs})"
  end

  # Merges parsed fragments into changelog_text's `## [Unreleased]` section,
  # grouping bullets under Keep a Changelog section headers (appending to
  # existing headers where present) and returns the updated changelog text.
  def self.merge(changelog_text, fragments)
    lines = changelog_text.lines
    start_idx = lines.index { |line| line.strip == UNRELEASED_HEADER }
    raise FragmentError, "CHANGELOG.md has no '#{UNRELEASED_HEADER}' section" unless start_idx

    rest = lines[(start_idx + 1)..] || []
    offset = rest.index { |line| line.start_with?('## ') }
    end_idx = offset.nil? ? lines.length : start_idx + 1 + offset

    sections = parse_sections(lines[(start_idx + 1)...end_idx])
    fragments.each do |fragment|
      title = SECTION_TITLES.fetch(fragment.fetch('change_type'))
      (sections[title] ||= []) << bullet_for(fragment)
    end

    (lines[0..start_idx] + [render_sections(sections)] + lines[end_idx..]).join
  end

  def self.parse_sections(body_lines)
    sections = {}
    current = nil
    body_lines.each do |line|
      if line.start_with?('### ')
        current = line.delete_prefix('### ').strip
        sections[current] ||= []
      elsif current && !line.strip.empty?
        sections[current] << line.rstrip
      end
    end
    sections
  end
  private_class_method :parse_sections

  def self.render_sections(sections)
    body = +"\n"
    SECTION_TITLES.each_value do |title|
      bullets = sections[title]
      next if bullets.nil? || bullets.empty?

      body << "### #{title}\n\n#{bullets.join("\n")}\n\n"
    end
    body
  end
  private_class_method :render_sections
end
