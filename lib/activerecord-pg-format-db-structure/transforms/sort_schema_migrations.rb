# frozen_string_literal: true

require_relative "base"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Sort schema migration inserts to reduce merge conflicts
    class SortSchemaMigrations < Base
      def transform!
        raw_statements.each do |raw_statement|
          next unless raw_statement.stmt.to_h in insert_stmt: {
            relation: { relname: "schema_migrations" },
            select_stmt: { select_stmt: { values_lists: _ } }
          }

          raw_statement.stmt.insert_stmt.select_stmt.select_stmt.values_lists.sort_by! do |list|
            list.list.items.first.a_const.sval.sval
          end
        end
      end
    end
  end
end
