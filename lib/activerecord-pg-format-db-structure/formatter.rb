# frozen_string_literal: true

require_relative "deparser"
require_relative "../activerecord-pg-format-db-structure"

module ActiveRecordPgFormatDbStructure
  # Formats & normalizes in place the given SQL string
  class Formatter
    attr_reader :preprocessors, :transforms, :deparser

    def initialize(
      preprocessors: DEFAULT_PREPROCESSORS,
      transforms: DEFAULT_TRANSFORMS,
      deparser: DEFAULT_DEPARSER
    )
      @preprocessors = preprocessors
      @transforms = transforms
      @deparser = deparser
    end

    def format(source)
      preprocessors.each do |preprocessor|
        preprocessor.new(source).preprocess!
      end

      raw_statements = PgQuery.parse(source).tree.stmts

      transforms.each do |transform|
        transform.new(raw_statements).transform!
      end

      raw_statements.map do |raw_statement|
        deparser.new(source).deparse_raw_statement(raw_statement)
      end.compact.join
    end
  end
end
