# frozen_string_literal: true

require "pg_query"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # :nodoc:
    class Base
      attr_reader :raw_statements

      def initialize(raw_statements)
        @raw_statements = raw_statements
      end
    end
  end
end
