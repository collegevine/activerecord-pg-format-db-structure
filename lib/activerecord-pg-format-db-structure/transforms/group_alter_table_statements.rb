# frozen_string_literal: true

require_relative "base"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Group alter table statements into one operation per
    # table. Should be run after other operations that inline alter statements.
    class GroupAlterTableStatements < Base
      def transform!
        alter_groups = extract_alter_table_statements!

        return if alter_groups.empty?

        insert_index = raw_statements.each_with_index.map do |s, i|
          # after all tables, materialized views and indices
          i if s.stmt.to_h in { create_stmt: _ } | { create_table_as_stmt: _ } | { index_stmt: _ }
        end.compact.last

        sort_groups(alter_groups).each do |_, alters| # rubocop:disable Style/HashEachMethods
          alter = sort_alters(alters).reduce do |altera, alterb|
            altera.stmt.alter_table_stmt.cmds = altera.stmt.alter_table_stmt.cmds + alterb.stmt.alter_table_stmt.cmds
            altera
          end
          raw_statements.insert(insert_index + 1, alter)
        end
      end

      private

      def sort_alters(alters)
        alters.sort_by do |alter|
          case alter.stmt.alter_table_stmt.to_h
          in cmds: [{
            alter_table_cmd: {
              subtype: :AT_AddConstraint,
              def: { constraint: {
                contype: :CONSTR_FOREIGN,
                fk_attrs: [{string: {sval: fk_attr}}],
              }}
            }
          }]
            [1, fk_attr]
          else
            [2, ""]
          end
        end
      end

      def sort_groups(groups)
        groups.sort_by { |relation, _| [relation[:schemaname], relation[:relname]] }.reverse
      end

      def extract_alter_table_statements!
        alter_groups = {}
        raw_statements.delete_if do |s|
          next unless s.stmt.to_h in alter_table_stmt: {
            objtype: :OBJECT_TABLE,
            relation: {
              schemaname:,
              relname:
            }
          }

          relation = { schemaname:, relname: }
          alter_groups[relation] ||= []
          alter_groups[relation] << s
          true
        end
        alter_groups
      end
    end
  end
end
