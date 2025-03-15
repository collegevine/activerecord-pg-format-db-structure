# frozen_string_literal: true

require_relative "deparser"
require_relative "../activerecord-pg-format-db-structure"

module ActiveRecordPgFormatDbStructure
  # Formats & normalizes in place the given SQL string
  class Formatter
    attr_reader :transforms, :deparser, :statement_appender

    def initialize(
      transforms: DEFAULT_TRANSFORMS,
      deparser: DEFAULT_DEPARSER,
      statement_appender: DEFAULT_STATEMENT_APPENDER
    )
      @transforms = transforms
      @deparser = deparser
      @statement_appender = statement_appender
    end

    def format(source)
      raw_statements = PgQuery.parse(source).tree.stmts

      transforms.each do |transform|
        transform.new(raw_statements).transform!
      end

      appender = statement_appender.new
      raw_statements.each do |raw_statement|
        statement = deparser.new(source).deparse_raw_statement(raw_statement)
        appender.append_statement!(
          statement,
          statement_kind: PgQuery::Node.inner_class_to_name(
            raw_statement.stmt.inner.class
          )
        )
      end
      appender.output
    end
  end
end
