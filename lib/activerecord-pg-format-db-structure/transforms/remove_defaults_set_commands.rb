# frozen_string_literal: true

require_relative "base"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Remove SET commands that apply default values to postgres settings
    class RemoveDefaultsSetCommands < Base
      class << self
        attr_accessor :postgres_config_defaults
      end

      self.postgres_config_defaults = {
        default_table_access_method: "heap",
        default_with_oids: false,
        idle_in_transaction_session_timeout: 0,
        lock_timeout: 0,
        statement_timeout: 0,
        transaction_timeout: 0,
        standard_conforming_strings: true,
        xmloption: "content"
      }

      def transform!
        raw_statements.delete_if do |raw_statement|
          next unless raw_statement.stmt.to_h in variable_set_stmt: {kind: :VAR_SET_VALUE, name:, args: [{a_const:}]}

          next unless self.class.postgres_config_defaults.key?(name.to_sym)

          pattern = value_to_pattern(self.class.postgres_config_defaults[name.to_sym])

          val_from_a_const(a_const) in ^pattern
        end
      end

      private

      def value_to_pattern(value)
        case value
        in false
          Set.new(["false", "no", "off", 0])
        in true
          Set.new(["true", "yes", "on", 1])
        else
          value
        end
      end

      def val_from_a_const(a_const)
        case a_const
        in ival:
          ival.fetch(:ival, 0)
        in sval:
          sval.fetch(:sval, "").downcase
        else
          a_const.values.first
        end
      end
    end
  end
end
