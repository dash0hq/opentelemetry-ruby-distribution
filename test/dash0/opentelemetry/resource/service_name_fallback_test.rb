# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    module Resource
      class ServiceNameFallbackTest < Minitest::Test
        include TestHelpers

        # The detector's only public method is `detect`; the helpers below are
        # internal and exercised via `send`. A `nil` root isolates the program-name
        # rung; a fixture root exercises the project-file rungs.

        # --- program-name rung -------------------------------------------------

        def test_derives_service_name_from_a_plain_script
          with_env(clear_service_name_env) do
            assert_equal 'my_app', ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb', nil)
          end
        end

        def test_refuses_wrapper_executables
          with_env(clear_service_name_env) do
            %w[/usr/local/bin/bundle /usr/bin/rails /app/bin/puma /usr/local/bin/rackup].each do |wrapper|
              assert_nil ServiceNameFallback.send(:fallback_service_name, wrapper, nil),
                         "expected #{wrapper} to be refused"
            end
          end
        end

        def test_returns_nil_when_program_name_unusable
          with_env(clear_service_name_env) do
            assert_nil ServiceNameFallback.send(:fallback_service_name, '', nil)
            assert_nil ServiceNameFallback.send(:fallback_service_name, nil, nil)
          end
        end

        # --- Rails / Hanami app module ----------------------------------------

        def test_derives_rails_app_name_from_config_application_rb
          application_rb = "module DemoApp\n  class Application < Rails::Application; end\nend\n"
          with_env(clear_service_name_env) do
            with_project('config/application.rb' => application_rb) do |root|
              # Wins even though the program is a wrapper.
              assert_equal 'demo_app', ServiceNameFallback.send(:fallback_service_name, '/usr/local/bin/bundle', root)
            end
          end
        end

        def test_derives_hanami_app_name_from_config_app_rb
          app_rb = "require 'hanami'\nmodule Bookshelf\n  class App < Hanami::App; end\nend\n"
          with_env(clear_service_name_env) do
            with_project('config/app.rb' => app_rb) do |root|
              assert_equal 'bookshelf', ServiceNameFallback.send(:fallback_service_name, '/usr/local/bin/bundle', root)
            end
          end
        end

        def test_underscores_acronym_style_module_names
          with_env(clear_service_name_env) do
            with_project('config/application.rb' => "module CheckoutAPI\nend\n") do |root|
              assert_equal 'checkout_api',
                           ServiceNameFallback.send(:fallback_service_name, '/usr/local/bin/bundle', root)
            end
          end
        end

        # --- config.ru ---------------------------------------------------------

        def test_derives_name_from_config_ru_run_target
          with_env(clear_service_name_env) do
            with_project('config.ru' => "require_relative 'app'\nrun MyApp\n") do |root|
              assert_equal 'my_app', ServiceNameFallback.send(:fallback_service_name, '/usr/local/bin/bundle', root)
            end
          end
        end

        def test_derives_name_from_config_ru_run_target_with_method_chain
          with_project('config.ru' => "require_relative 'app'\nrun CheckoutApi.freeze.app\n") do |root|
            assert_equal 'checkout_api', ServiceNameFallback.send(:derive_from_config_ru, root)
          end
        end

        def test_derives_single_file_rails_name_from_config_ru
          with_project('config.ru' => "class Blog < Rails::Application\nend\nrun Blog\n") do |root|
            assert_equal 'blog', ServiceNameFallback.send(:derive_from_config_ru, root)
          end
        end

        def test_config_ru_framework_generic_yields_no_name
          # `run Rails.application` / `run Sinatra::Application` carry no identity.
          with_project('config.ru' => "require_relative 'config/environment'\nrun Rails.application\n") do |root|
            assert_nil ServiceNameFallback.send(:derive_from_config_ru, root)
          end
          with_project('config.ru' => "require './app'\nrun Sinatra::Application\n") do |root|
            assert_nil ServiceNameFallback.send(:derive_from_config_ru, root)
          end
        end

        def test_app_module_wins_over_config_ru
          files = {
            'config/application.rb' => "module DemoApp\nend\n",
            'config.ru' => "run SomethingElse\n"
          }

          with_project(files) do |root|
            assert_equal 'demo_app', ServiceNameFallback.send(:name_from_project, root)
          end
        end

        # --- root discovery ----------------------------------------------------

        def test_app_root_walks_up_to_the_project_root
          with_project('Gemfile' => "source 'https://rubygems.org'\n",
                       'config/application.rb' => "module DemoApp\nend\n") do |root|
            nested = File.join(root, 'app', 'jobs')
            FileUtils.mkdir_p(nested)

            assert_equal File.expand_path(root), ServiceNameFallback.send(:app_root, nested)
          end
        end

        def test_falls_back_to_script_name_when_no_project_files
          with_env(clear_service_name_env) do
            with_project({}) do |root|
              assert_equal 'my_worker', ServiceNameFallback.send(:fallback_service_name, '/app/my_worker.rb', root)
            end
          end
        end

        def test_returns_nil_for_wrapper_with_no_project
          with_env(clear_service_name_env) do
            with_project({}) do |root|
              assert_nil ServiceNameFallback.send(:fallback_service_name, '/usr/local/bin/bundle', root)
            end
          end
        end

        # --- opt-out / already-configured -------------------------------------

        def test_opted_out_disables_fallback
          with_env(clear_service_name_env.merge('DASH0_AUTOMATIC_SERVICE_NAME' => 'false')) do
            assert_nil ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb', nil)
          end
        end

        def test_otel_service_name_disables_fallback
          with_env(clear_service_name_env.merge('OTEL_SERVICE_NAME' => 'explicit')) do
            assert_nil ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb', nil)
          end
        end

        def test_service_name_in_resource_attributes_disables_fallback
          with_env(clear_service_name_env.merge('OTEL_RESOURCE_ATTRIBUTES' => 'service.name=explicit,foo=bar')) do
            assert_nil ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb', nil)
          end
        end

        def test_service_name_in_resource_attributes_strips_quotes
          with_env(clear_service_name_env.merge('OTEL_RESOURCE_ATTRIBUTES' => 'service.name="explicit"')) do
            assert ServiceNameFallback.send(:service_name_in_resource_attributes?)
          end
        end

        def test_empty_service_name_in_resource_attributes_does_not_disable_fallback
          with_env(clear_service_name_env.merge('OTEL_RESOURCE_ATTRIBUTES' => 'service.name=,foo=bar')) do
            assert_equal 'my_app', ServiceNameFallback.send(:fallback_service_name, '/path/to/my_app.rb', nil)
          end
        end

        private

        def with_project(files)
          Dir.mktmpdir do |dir|
            files.each do |relative_path, contents|
              path = File.join(dir, relative_path)
              FileUtils.mkdir_p(File.dirname(path))
              File.write(path, contents)
            end
            yield dir
          end
        end

        def clear_service_name_env
          {
            'DASH0_AUTOMATIC_SERVICE_NAME' => nil,
            'OTEL_SERVICE_NAME' => nil,
            'OTEL_RESOURCE_ATTRIBUTES' => nil
          }
        end
      end
    end
  end
end
