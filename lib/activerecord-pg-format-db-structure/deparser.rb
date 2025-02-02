# frozen_string_literal: true

require "pg_query"
require_relative "indenter"

module ActiveRecordPgFormatDbStructure
  # Returns a list of SQL strings from a list of PgQuery::RawStmt.
  class Deparser
    attr_reader :source

    def initialize(source)
      @source = source
    end

    def deparse_raw_statement(raw_statement)
      case raw_statement.to_h
      in stmt: { insert_stmt: _ }
        deparse_insert_stmt(raw_statement.stmt.insert_stmt)
      in stmt: { create_stmt: _ }
        deparse_create_stmt(raw_statement.stmt.create_stmt)
      in stmt: { index_stmt: _ }
        deparse_stmt_compact(raw_statement.stmt.index_stmt)
      else
        deparse_stmt_generic(raw_statement.stmt.inner)
      end
    end

    private

    def deparse_stmt_generic(stmt)
      generic_str = +"\n\n"
      generic_str << deparse_stmt_and_indent(stmt)
      generic_str << ";"
      generic_str
    end

    def deparse_stmt_compact(stmt)
      compact_str = +"\n"
      compact_str << deparse_stmt(stmt)
      compact_str << ";"
      compact_str
    end

    def deparse_insert_stmt(stmt)
      insert_str = +"\n\n\n"
      insert_str << deparse_stmt_and_indent(stmt)
      insert_str << "\n;"
      insert_str
    end

    def deparse_create_stmt(create_stmt)
      table_str = "\n\n\n-- Name: #{create_stmt.relation.relname}; Type: TABLE;\n\n"
      table_str << deparse_stmt_and_indent(create_stmt)
      table_str << ";"
      table_str
    end

    def deparse_stmt_and_indent(stmt)
      Indenter.new(deparse_stmt(stmt)).indent
    end

    def deparse_stmt(stmt)
      PgQuery.deparse_stmt(stmt)
    end
  end
end
