# frozen_string_literal: true

require_relative "base"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Move indice declaration just below the table they index
    class MoveIndicesAfterCreateTable < Base
      def transform!
        extract_table_indices!.each do |table, indices|
          insert_index = find_insert_index(**table)
          sort_indices(indices).reverse.each do |index|
            raw_statements.insert(insert_index + 1, index)
          end
        end
      end

      private

      def find_insert_index(schemaname:, relname:)
        raw_statements.find_index do |s|
          s.stmt.to_h in {
            create_stmt: { relation: { schemaname: ^schemaname, relname: ^relname } }
          } | {
            create_table_as_stmt: { into: { rel: { schemaname: ^schemaname, relname: ^relname } }}
          }
        end
      end

      def sort_indices(indices)
        indices.sort_by do |s|
          [
            s.stmt.index_stmt.unique ? 0 : 1, # unique indices first
            s.stmt.index_stmt.idxname
          ]
        end
      end

      def extract_table_indices!
        indices = raw_statements.select { |s| s.stmt.to_h in index_stmt: _ }
        raw_statements.delete_if { |s| s.stmt.to_h in index_stmt: _ }
        indices.group_by do |s|
          {
            schemaname: s.stmt.index_stmt.relation.schemaname,
            relname: s.stmt.index_stmt.relation.relname
          }
        end
      end
    end
  end
end
