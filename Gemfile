# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

source 'https://rubygems.org'

gemspec

group :test do
  gem 'minitest', '~> 5.25'
  gem 'rake', '~> 13.2'
  gem 'rubocop', '~> 1.72'
  gem 'rubocop-minitest', '~> 0.36'
  gem 'rubocop-performance', '~> 1.23'
  gem 'rubocop-rake', '~> 0.6'
  gem 'simplecov', '~> 0.22', require: false
  gem 'webrick', '~> 1.9' # mock OTLP/HTTP collector for integration tests

  # Minimal Rails stack for the default-stack integration smoke. railties +
  # actionpack only (no ActiveRecord), so there are no native DB dependencies.
  gem 'actionpack', '~> 7.2'
  gem 'railties', '~> 7.2'
end
