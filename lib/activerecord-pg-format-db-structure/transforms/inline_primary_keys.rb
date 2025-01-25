# frozen_string_literal: true

require "pg_query"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Inlines primary keys with the table declaration
    class InlinePrimaryKeys
      attr_reader :raw_statements

      def initialize(raw_statements)
        @raw_statements = raw_statements
        @columns_with_primary_key = {}
      end

      def transform!
        extract_primary_keys_to_inline!
        raw_statements.each do |raw_statement|
          next unless raw_statement.stmt.to_h in create_stmt: { relation: { schemaname:, relname: }}

          relation = { schemaname:, relname: }
          primary_key = @columns_with_primary_key[relation]
          add_primary_key!(raw_statement, primary_key) if primary_key
        end
      end

      private

      def extract_primary_keys_to_inline!
        raw_statements.delete_if do |raw_statement|
          next unless match_alter_column_statement(raw_statement) in { schemaname:, relname:, colname: }

          column = { schemaname:, relname:, colname: }
          table = column.except(:colname)
          @columns_with_primary_key[table] = column[:colname]

          true
        end
      end

      def match_alter_column_statement(raw_statement)
        return unless raw_statement.stmt.to_h in {
          alter_table_stmt: {
            objtype: :OBJECT_TABLE,
            relation: {
              schemaname:,
              relname:
            },
            cmds: [{
              alter_table_cmd: {
                subtype: :AT_AddConstraint,
                def: {
                  constraint: {
                    contype: :CONSTR_PRIMARY,
                    conname: _,
                    keys: [{string: {sval: colname}}]
                  }
                },
                behavior: :DROP_RESTRICT
              }
            }]
          }
        }

        { schemaname:, relname:, colname: }
      end

      def add_primary_key!(raw_statement, colname)
        raw_statement.stmt.create_stmt.table_elts.each do |table_elt|
          next unless table_elt.to_h in { column_def: { colname: ^colname } }

          table_elt.column_def.constraints.delete_if do |c|
            c.to_h in { constraint: { contype: :CONSTR_NOTNULL } }
          end

          table_elt.column_def.constraints << PgQuery::Node.new(
            constraint: PgQuery::Constraint.new(
              contype: :CONSTR_PRIMARY
            )
          )
        end
      end
    end
  end
end
