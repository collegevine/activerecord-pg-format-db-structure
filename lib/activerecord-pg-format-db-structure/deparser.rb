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
      in stmt: { view_stmt: _ }
        deparse_view_stmt(raw_statement.stmt.view_stmt)
      in stmt: { create_table_as_stmt: _ }
        deparse_create_table_as_stmt(raw_statement.stmt.create_table_as_stmt)
      in stmt: { index_stmt: _ }
        deparse_stmt_compact(raw_statement.stmt.index_stmt)
      else
        deparse_stmt_generic(raw_statement.stmt.inner)
      end
    end

    private

    def deparse_stmt_generic(stmt)
      generic_str = +""
      generic_str << deparse_stmt_and_indent(stmt)
      generic_str << ";"
      generic_str
    end

    def deparse_stmt_compact(stmt)
      compact_str = +""
      compact_str << deparse_stmt(stmt)
      compact_str << ";"
      compact_str
    end

    def deparse_insert_stmt(stmt)
      insert_str = +""
      insert_str << deparse_stmt_and_indent(stmt)
      insert_str << "\n;"
      insert_str
    end

    def deparse_create_stmt(stmt)
      table_str = "-- Name: #{stmt.relation.relname}; Type: TABLE;\n\n"
      table_str << deparse_stmt_and_indent(stmt)
      table_str << ";"
      table_str
    end

    def deparse_view_stmt(stmt)
      table_str = "-- Name: #{stmt.view.relname}; Type: VIEW;\n\n"
      table_str << deparse_stmt_and_indent(stmt)
      table_str << ";"
      table_str
    end

    def deparse_create_table_as_stmt(stmt)
      table_str = "-- Name: #{stmt.into.rel.relname}; Type: MATERIALIZED VIEW;\n\n"
      table_str << deparse_stmt_and_indent(stmt)

      # couldn't find a better solution for this, but probably an OK workaround?
      table_str.gsub!(/ WITH NO DATA\z/, "\nWITH NO DATA")

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
