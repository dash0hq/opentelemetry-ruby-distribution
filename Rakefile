# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

namespace :test do
  Rake::TestTask.new :unit do |t|
    t.libs << 'test'
    t.libs << 'lib'
    t.test_files = FileList['test/dash0/**/*_test.rb']
    t.warning = false
  end

  Rake::TestTask.new :integration do |t|
    t.libs << 'test'
    t.libs << 'lib'
    t.test_files = FileList['test/integration/**/*_test.rb']
    t.warning = false
  end
end

desc 'Run all tests (unit + integration)'
task test: %w[test:unit test:integration]

task default: %i[test rubocop]
