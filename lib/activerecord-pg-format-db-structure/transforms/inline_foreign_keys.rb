# frozen_string_literal: true

require "pg_query"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Inline foreign key constraints.
    #
    # Note: using this transform makes the structure file no longer
    # loadable, since tables should be created before a foreign key
    # can target it.
    class InlineForeignKeys
      attr_reader :raw_statements

      def initialize(raw_statements)
        @raw_statements = raw_statements
        @columns_with_foreign_key = {}
      end

      def transform!
        extract_foreign_keys_to_inline!
        raw_statements.each do |raw_statement|
          next unless raw_statement.stmt.to_h in create_stmt: { relation: { schemaname:, relname: }}

          relation = { schemaname:, relname: }
          next unless @columns_with_foreign_key.include?(relation)

          @columns_with_foreign_key[relation].each do |column_name, constraint|
            add_constraint!(raw_statement, column_name, constraint)
          end
        end
      end

      private

      def extract_foreign_keys_to_inline!
        raw_statements.delete_if do |raw_statement|
          next unless match_alter_column_statement(raw_statement) in { column:, constraint: }

          table = column.except(:colname)
          @columns_with_foreign_key[table] ||= {}
          @columns_with_foreign_key[table][column[:colname]] = constraint

          true
        end
      end

      def match_alter_column_statement(raw_statement)
        # Extracting statements of this shape:
        #
        # ALTER TABLE ONLY ts.tn ALTER COLUMN c SET DEFAULT nextval('ts.tn_c_seq'::regclass);
        #
        # Which corresponds to what we get when using a SERIAL column
        if raw_statement.stmt.to_h in {
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
                    contype: :CONSTR_FOREIGN,
                    conname:,
                    initially_valid:,
                    pktable:,
                    fk_attrs: [{string: {sval: colname}}],
                    pk_attrs:,
                    fk_matchtype:,
                    fk_upd_action:,
                    fk_del_action:
                  }
                },
                behavior: :DROP_RESTRICT
              }
            }]
          }
        }
          {
            column: { schemaname:, relname:, colname: },
            constraint: {
              contype: :CONSTR_FOREIGN,
              conname:,
              initially_valid:,
              pktable:,
              pk_attrs:,
              fk_matchtype:,
              fk_upd_action:,
              fk_del_action:
            }
          }
        end
      end

      def add_constraint!(raw_statement, colname, constraint)
        raw_statement.stmt.create_stmt.table_elts.each do |table_elt|
          next unless table_elt.to_h in { column_def: { colname: ^colname } }

          table_elt.column_def.constraints << PgQuery::Node.new(
            constraint: PgQuery::Constraint.new(constraint)
          )
        end
      end
    end
  end
end
