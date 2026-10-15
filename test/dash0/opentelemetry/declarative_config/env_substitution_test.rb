# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'date'
require 'yaml'
require 'dash0/opentelemetry'

module Dash0
  module OpenTelemetry
    module DeclarativeConfig
      class EnvSubstitutionTest < Minitest::Test
        # Environment from the data model specification's substitution examples.
        ENV_VARS = {
          'STRING_VALUE' => 'value',
          'BOOL_VALUE' => 'true',
          'INT_VALUE' => '1',
          'FLOAT_VALUE' => '1.1',
          'HEX_VALUE' => '0xdeadbeef',
          'INVALID_MAP_VALUE' => "value\nkey:value",
          'DO_NOT_REPLACE_ME' => 'Never use this value',
          'REPLACE_ME' => '${DO_NOT_REPLACE_ME}',
          'VALUE_WITH_ESCAPE' => 'value$$',
          'EMPTY_VALUE' => ''
        }.freeze

        # Substitution examples from the data model specification.
        EXAMPLES = {
          '${STRING_VALUE}' => 'value',
          '${BOOL_VALUE}' => true,
          '${INT_VALUE}' => 1,
          '${FLOAT_VALUE}' => 1.1,
          '${HEX_VALUE}' => 3_735_928_559,
          '"${STRING_VALUE}"' => 'value',
          '"${BOOL_VALUE}"' => 'true',
          '"${INT_VALUE}"' => '1',
          '"${FLOAT_VALUE}"' => '1.1',
          '"${HEX_VALUE}"' => '0xdeadbeef',
          '${env:STRING_VALUE}' => 'value',
          '${INVALID_MAP_VALUE}' => "value\nkey:value",
          'foo ${STRING_VALUE} ${FLOAT_VALUE}' => 'foo value 1.1',
          '${UNDEFINED_KEY}' => nil,
          '${UNDEFINED_KEY:-fallback}' => 'fallback',
          '${EMPTY_VALUE:-fallback}' => 'fallback',
          '${REPLACE_ME}' => '${DO_NOT_REPLACE_ME}',
          '${UNDEFINED_KEY:-${STRING_VALUE}}' => '${STRING_VALUE}',
          '$${STRING_VALUE}' => '${STRING_VALUE}',
          '$$${STRING_VALUE}' => '$value',
          '$$$${STRING_VALUE}' => '$${STRING_VALUE}',
          '$${STRING_VALUE:-fallback}' => '${STRING_VALUE:-fallback}',
          '$${STRING_VALUE:-${STRING_VALUE}}' => '${STRING_VALUE:-value}',
          '${UNDEFINED_KEY:-$${UNDEFINED_KEY}}' => '${UNDEFINED_KEY:-${UNDEFINED_KEY}}',
          '${VALUE_WITH_ESCAPE}' => 'value$$',
          'a $$ b' => 'a $ b',
          'a $ b' => 'a $ b'
        }.freeze

        def test_spec_examples
          EXAMPLES.each do |input, expected|
            actual = load_value(input)
            if expected.nil?
              assert_nil actual, "key: #{input}"
            else
              assert_equal expected, actual, "key: #{input}"
            end
          end
        end

        def test_does_not_substitute_mapping_keys
          assert_equal({ '${STRING_VALUE}' => 'value' }, EnvSubstitution.load('${STRING_VALUE}: value', ENV_VARS))
        end

        def test_substitutes_nested_scalars_and_sequence_items
          result = EnvSubstitution.load(<<~YAML, ENV_VARS)
            outer:
              inner: ${STRING_VALUE}
              list:
                - ${INT_VALUE}
                - name: ${BOOL_VALUE}
          YAML

          assert_equal({ 'outer' => { 'inner' => 'value', 'list' => [1, { 'name' => true }] } }, result)
        end

        def test_raises_on_invalid_references
          ['${STRING_VALUE:?error}', '${1API_KEY}', '${sys:STRING_VALUE}'].each do |input|
            assert_raises(EnvSubstitution::Error, input) { load_value(input) }
          end
        end

        def test_returns_nil_for_an_empty_document
          assert_nil EnvSubstitution.load('', ENV_VARS)
        end

        def test_rejects_disallowed_classes_and_aliases
          assert_raises(Psych::DisallowedClass) { EnvSubstitution.load('key: !ruby/object:Object {}', ENV_VARS) }
          assert_raises(Psych::AliasesNotEnabled) { EnvSubstitution.load("a: &x 1\nb: *x", ENV_VARS) }
        end

        private

        def load_value(yaml)
          EnvSubstitution.load("key: #{yaml}", ENV_VARS)['key']
        end
      end
    end
  end
end
