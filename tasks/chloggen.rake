# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'fileutils'
require 'securerandom'
require_relative 'chloggen'

CHLOGGEN_DIR = File.expand_path('../.chloggen', __dir__)
CHLOGGEN_TEMPLATE = File.join(CHLOGGEN_DIR, 'TEMPLATE.yaml')
CHLOGGEN_CHANGELOG_PATH = File.expand_path('../CHANGELOG.md', __dir__)

def chloggen_fragment_paths
  Dir.glob(File.join(CHLOGGEN_DIR, '*.yaml')).reject { |path| File.basename(path) == 'TEMPLATE.yaml' }.sort
end

# Renders a message as a GitHub Actions error annotation when running in CI, so
# the failure shows up on the pull request and not only in the job log.
def chloggen_error(message)
  ENV['GITHUB_ACTIONS'] == 'true' ? "::error::#{message}" : message
end

namespace :chloggen do
  desc 'Create a new changelog fragment: rake "chloggen:new[short-slug]"'
  task :new, [:slug] do |_t, args|
    slug = args[:slug].to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
    slug = SecureRandom.hex(4) if slug.empty?
    dest = File.join(CHLOGGEN_DIR, "#{slug}.yaml")
    abort("#{dest} already exists") if File.exist?(dest)

    FileUtils.cp(CHLOGGEN_TEMPLATE, dest)
    puts "Created #{dest} - fill it in and commit it alongside your change."
  end

  desc 'Validate changelog fragments in .chloggen/'
  task :validate do
    paths = chloggen_fragment_paths
    if paths.empty?
      puts 'No changelog fragments to validate.'
      next
    end

    failed = false
    paths.each do |path|
      Chloggen.parse_fragment(File.read(path))
    rescue Chloggen::FragmentError => e
      warn "#{path}: #{e.message}"
      failed = true
    end
    abort('Changelog fragment validation failed.') if failed
    puts "#{paths.size} changelog fragment(s) OK."
  end

  desc 'Check a PR\'s changed files carry a fragment: rake "chloggen:required[changed-files.txt]"'
  task :required, [:changed_files] do |_t, args|
    list_path = args[:changed_files].to_s
    abort('Usage: rake "chloggen:required[path/to/changed-files.txt]"') if list_path.empty?
    abort("#{list_path} does not exist") unless File.exist?(list_path)

    changed_files = File.readlines(list_path, chomp: true).reject(&:empty?)
    shipped = Chloggen.shipped_changes(changed_files)
    if shipped.empty?
      puts 'No changes to shipped code or shipped dependencies, no changelog fragment needed.'
      next
    end

    puts 'Changes that reach users, and therefore need a changelog fragment:'
    shipped.each { |path| puts "  #{path}" }

    fragments = Chloggen.fragment_changes(changed_files)
    if fragments.empty?
      abort chloggen_error(
        "This PR changes shipped code or shipped dependencies (#{shipped.join(', ')}) but adds no " \
        ".chloggen/*.yaml fragment. Add one with 'bundle exec rake chloggen:new[slug]' (on a dependabot " \
        "branch: push a fragment describing the dependency bump), or apply the 'Skip changelog' label."
      )
    end

    puts 'Found changelog fragment(s):'
    fragments.each { |path| puts "  #{path}" }
  end

  desc 'Merge changelog fragments into CHANGELOG.md and delete them'
  task :update do
    paths = chloggen_fragment_paths
    abort('No changelog fragments found in .chloggen/.') if paths.empty?

    fragments = paths.map { |path| Chloggen.parse_fragment(File.read(path)) }
    File.write(CHLOGGEN_CHANGELOG_PATH, Chloggen.merge(File.read(CHLOGGEN_CHANGELOG_PATH), fragments))
    paths.each { |path| File.delete(path) }
    puts "Merged #{fragments.size} changelog fragment(s) into CHANGELOG.md."
  end
end
