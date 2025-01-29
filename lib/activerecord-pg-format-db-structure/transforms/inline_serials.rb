# frozen_string_literal: true

require_relative "base"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Inline SERIAL declaration inside table declaration.
    #
    # Note: the logic looks for statements of this shape:
    #
    #    ALTER TABLE ONLY ts.tn ALTER COLUMN c SET DEFAULT nextval('ts.tn_c_seq'::regclass);
    #
    # It also assumes that the associated sequence has default settings. A
    # later version could try to be more strict / validate that the
    # sequence indeed has default settings.
    class InlineSerials < Base
      def transform!
        extract_serials_to_inline! => columns_to_replace_with_serial:, sequences_to_remove:
        delete_redundant_statements!(sequences_to_remove)
        raw_statements.each do |raw_statement|
          next unless raw_statement.stmt.to_h in create_stmt: { relation: { schemaname:, relname: }}

          relation = { schemaname:, relname: }
          next unless columns_to_replace_with_serial.include?(relation)

          columns_to_replace_with_serial[relation].each do |colname|
            replace_id_with_serial!(raw_statement, colname)
          end
        end
      end

      private

      def extract_serials_to_inline!
        columns_to_replace_with_serial = {}
        sequences_to_remove = Set.new
        raw_statements.delete_if do |raw_statement|
          next unless match_alter_column_statement(raw_statement) in { column:, sequence: }

          table = column.except(:column_name)
          columns_to_replace_with_serial[table] ||= []
          columns_to_replace_with_serial[table] << column[:column_name]
          sequences_to_remove << sequence

          true
        end
        { columns_to_replace_with_serial:, sequences_to_remove: }
      end

      def match_alter_column_statement(raw_statement)
        # Extracting statements of this shape:
        #
        # ALTER TABLE ONLY ts.tn ALTER COLUMN c SET DEFAULT nextval('ts.tn_c_seq'::regclass);
        #
        # Which corresponds to what we get when using a SERIAL column
        return unless raw_statement.stmt.to_h in {
          alter_table_stmt: {
            objtype: :OBJECT_TABLE,
            relation: {
              schemaname:,
              relname:
            },
            cmds: [{
              alter_table_cmd: {
                subtype: :AT_ColumnDefault,
                name: column_name,
                def: {
                  func_call: {
                    funcname: [{string: {sval: "nextval"}}],
                    args: [{ type_cast: {arg: {a_const: {sval: {sval: sequence_qualified_name}}},
                                         type_name: {names: [{string: {sval: "regclass"}}]}}}],
                    funcformat: :COERCE_EXPLICIT_CALL
                  }
                },
                behavior: :DROP_RESTRICT
              }
            }]
          }
        }
        return unless sequence_qualified_name == "#{schemaname}.#{relname}_#{column_name}_seq"

        {
          column: { schemaname:, relname:, column_name: },
          sequence: { schemaname:, relname: "#{relname}_#{column_name}_seq" }
        }
      end

      COLUMN_TYPE_TO_SERIAL_TYPE = {
        "int2" => "smallserial",
        "int4" => "serial",
        "int8" => "bigserial"
      }.freeze

      def replace_id_with_serial!(raw_statement, colname)
        raw_statement.stmt.create_stmt.table_elts.each do |table_elt|
          next unless table_elt.to_h in {
            column_def: {
              colname: ^colname,
              type_name: { names: [{string: {sval: "pg_catalog"}},
                                   {string: {sval: "int2" | "int4" | "int8" => integer_type}}] }}
          }

          table_elt.column_def.type_name = PgQuery::TypeName.new(
            names: [
              PgQuery::Node.from_string(
                COLUMN_TYPE_TO_SERIAL_TYPE.fetch(integer_type)
              )
            ]
          )
        end
      end

      def delete_redundant_statements!(sequences_to_remove)
        raw_statements.delete_if do |raw_statement|
          case raw_statement.stmt.to_h
          in create_seq_stmt: { sequence: { schemaname:, relname: }}
            sequences_to_remove.include?({ schemaname:, relname: })
          in alter_seq_stmt: {sequence: { schemaname:, relname: }}
            sequences_to_remove.include?({ schemaname:, relname: })
          else
            false
          end
        end
      end
    end
  end
end
