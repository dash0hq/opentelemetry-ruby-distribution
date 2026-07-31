# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

module Dash0
  module OpenTelemetry
    module Resource
      # Resource detector that provides a fallback `service.name` when none has
      # been configured, derived from the application's own identity.
      #
      # Because the distribution boots at interpreter startup via `RUBYOPT`, the
      # program name is usually the wrapper the container runs (`bundle`, `puma`,
      # `rackup`), not the application. Sampling that would report every Ruby
      # service under the same meaningless name, so instead we read the app's
      # identity from its project files, best signal first:
      #
      #   1. `config/application.rb` / `config/app.rb` `module <Name>` — Rails, Hanami
      #   2. `config.ru` — the `run <AppClass>` target or an inline app class
      #      (modular Sinatra, Roda, plain Rack, single-file Rails)
      #   3. the entry script name, when it is not a known wrapper
      #
      # When none of these yields a name (e.g. a classic Sinatra app run through a
      # wrapper), we return nil and let the SDK's `unknown_service` stand — honest
      # absence beats a wrapper's name.
      #
      # The fallback is skipped when a service name is already configured via
      # `OTEL_SERVICE_NAME` or a `service.name` in `OTEL_RESOURCE_ATTRIBUTES`, or
      # when opted out with `DASH0_AUTOMATIC_SERVICE_NAME=false`.
      #
      # `OpenTelemetry::SDK` must be loaded before `detect` is called.
      module ServiceNameFallback
        AUTOMATIC_SERVICE_NAME_ENV = 'DASH0_AUTOMATIC_SERVICE_NAME'
        SERVICE_NAME_KEY = 'service.name'

        # Files whose top-level `module <Name>` names the application (Rails, Hanami).
        APP_MODULE_FILES = ['config/application.rb', 'config/app.rb'].freeze
        CONFIG_RU = 'config.ru'
        # Any of these in a directory marks it as a plausible application root.
        PROJECT_MARKERS = (APP_MODULE_FILES + [CONFIG_RU, 'Gemfile']).freeze
        # How far up from the working directory to look for the application root.
        MAX_ROOT_WALK = 4
        # Config files are tiny; cap the read so a pathological file can't stall boot.
        MAX_CONFIG_BYTES = 64 * 1024

        # Program names that are wrappers/launchers rather than the application, so
        # they carry no service identity and must not be used as a name.
        WRAPPER_EXECUTABLES = %w[
          bundle bundler rake rackup ruby irb spring rails
          puma unicorn thin falcon sidekiq resque foreman
        ].freeze

        # A `run <X>` / `class < <X>` target whose leading constant is one of these
        # is a framework generic (`run Rails.application`, `run Sinatra::Application`),
        # not the app's own name, so it is not a usable signal.
        FRAMEWORK_GENERICS = %w[Rails Sinatra Hanami Rack].freeze

        extend self

        # The detector interface: the only public method.
        def detect
          attributes = {}
          name = fallback_service_name
          attributes[SERVICE_NAME_KEY] = name if name
          ::OpenTelemetry::SDK::Resources::Resource.create(attributes)
        end

        private

        # @return [String, nil] the derived service name, or nil when a name is
        #   already configured, the fallback is opted out, or none can be derived.
        def fallback_service_name(program_name = $PROGRAM_NAME, root = app_root)
          return nil if service_name_configured?

          name_from_project(root) || derive_from_program_name(program_name)
        end

        def name_from_project(root)
          return nil unless root

          derive_from_app_module(root) || derive_from_config_ru(root)
        end

        # Rails/Hanami: the top-level `module <Name>` in the app's config file.
        def derive_from_app_module(root)
          APP_MODULE_FILES.each do |relative_path|
            source = read_project_file(root, relative_path)
            next unless source

            match = source.match(/^module\s+([A-Z]\w*)/)
            return underscore(match[1]) if match
          end
          nil
        end

        # config.ru: an inline app class (single-file Rails, inline Sinatra) or the
        # `run <AppClass>` target. Framework generics (`Rails.application`,
        # `Sinatra::Application`) carry no identity and are skipped.
        def derive_from_config_ru(root)
          source = read_project_file(root, CONFIG_RU)
          return nil unless source

          inline = source.match(/^\s*class\s+([A-Z]\w*)\s*<\s*(?:Rails::Application|Sinatra::(?:Base|Application))/)
          return underscore(inline[1]) if inline

          run_target = source.match(/^\s*run\s+\(?\s*([A-Z]\w*(?:::[A-Z]\w*)*)/)
          if run_target && !FRAMEWORK_GENERICS.include?(run_target[1].split('::').first)
            return underscore(run_target[1])
          end

          nil
        end

        def derive_from_program_name(program_name)
          return nil if program_name.nil?

          name = File.basename(program_name.to_s).delete_suffix('.rb')
          return nil if name.empty? || WRAPPER_EXECUTABLES.include?(name)

          name
        end

        # Walks up from the working directory to the nearest ancestor that looks
        # like an application root, or nil if none is found within MAX_ROOT_WALK.
        def app_root(start = Dir.pwd)
          dir = File.expand_path(start)
          MAX_ROOT_WALK.times do
            return dir if PROJECT_MARKERS.any? { |marker| File.readable?(File.join(dir, marker)) }

            parent = File.dirname(dir)
            break if parent == dir

            dir = parent
          end
          nil
        rescue StandardError
          nil
        end

        def read_project_file(root, relative_path)
          path = File.join(root, relative_path)
          return nil unless File.readable?(path)

          File.read(path, MAX_CONFIG_BYTES)
        rescue StandardError
          nil
        end

        # CamelCase / namespaced constant to snake_case: DemoApp -> demo_app,
        # CheckoutAPI -> checkout_api, MyApp::Web -> my_app_web.
        def underscore(name)
          name
            .gsub('::', '_')
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .tr('-', '_')
            .downcase
        end

        def service_name_configured?
          opted_out? || otel_service_name_set? || service_name_in_resource_attributes?
        end

        def opted_out?
          Environment.opted_out?(AUTOMATIC_SERVICE_NAME_ENV)
        end

        def otel_service_name_set?
          Environment.present?('OTEL_SERVICE_NAME')
        end

        # Parses OTEL_RESOURCE_ATTRIBUTES the same way the upstream env detector
        # does, stripping surrounding quotes, to see if a non-empty service.name
        # is present.
        def service_name_in_resource_attributes?
          raw = ENV.fetch('OTEL_RESOURCE_ATTRIBUTES', nil)
          return false if raw.nil? || raw.strip.empty?

          raw.split(',').any? do |pair|
            key, value = pair.split('=', 2)
            next false unless value && key.strip == SERVICE_NAME_KEY

            !value.strip.gsub(/\A"|"\z/, '').strip.empty?
          end
        end
      end
    end
  end
end
