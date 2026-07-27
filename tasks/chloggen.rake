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
