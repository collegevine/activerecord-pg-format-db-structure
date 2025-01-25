# frozen_string_literal: true

require "pg_query"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Remove COMMENT statement applied to extensions
    class RemoveCommentsOnExtensions
      attr_reader :raw_statements

      def initialize(raw_statements)
        @raw_statements = raw_statements
      end

      def transform!
        raw_statements.delete_if do |raw_statement|
          raw_statement.stmt.to_h in {
            comment_stmt: { objtype: :OBJECT_EXTENSION }
          }
        end
      end
    end
  end
end
