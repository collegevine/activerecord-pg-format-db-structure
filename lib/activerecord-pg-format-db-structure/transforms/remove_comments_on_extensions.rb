# frozen_string_literal: true

require_relative "base"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Remove COMMENT statement applied to extensions
    class RemoveCommentsOnExtensions < Base
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
