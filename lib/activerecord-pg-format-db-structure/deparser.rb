# frozen_string_literal: true

require "pg_query"

module ActiveRecordPgFormatDbStructure
  # Returns a list of SQL strings from a list of PgQuery::RawStmt.
  class Deparser
    attr_reader :source

    def initialize(source)
      @source = source
    end

    def deparse_raw_statement(raw_statement)
      case raw_statement.to_h
      in stmt: { create_stmt: _ }
        deparse_create_stmt(raw_statement.stmt.create_stmt)
      in stmt: { index_stmt: _ }
        deparse_index_stmt(raw_statement.stmt.index_stmt)
      in stmt: { alter_table_stmt: _ }
        deparse_alter_table_stmt(raw_statement.stmt.alter_table_stmt)
      else
        keep_original_string(raw_statement)
      end
    end

    private

    def keep_original_string(raw_statement)
      start = raw_statement.stmt_location || 0
      stop = start + raw_statement.stmt_len
      source[start..stop]
    end

    def deparse_alter_table_stmt(alter_table_stmt)
      "\n#{
        deparse_stmt(alter_table_stmt)
          .gsub(" ADD ", "\n  ADD ")
          .gsub(" ALTER COLUMN ", "\n  ALTER COLUMN ")
      }"
    end

    def deparse_stmt(stmt)
      "\n#{PgQuery.deparse_stmt(stmt)};"
    end

    def deparse_index_stmt(index_stmt)
      deparse_stmt(index_stmt)
    end

    def deparse_create_stmt(create_stmt)
      placeholder_column = PgQuery::Node.from(
        PgQuery::ColumnDef.new(
          colname: "placeholder_column",
          type_name: {
            names: [PgQuery::Node.from_string("placeholder_type")]
          }
        )
      )

      table_str = "\n\n\n-- Name: #{create_stmt.relation.relname}; Type: TABLE;\n\n"
      table_str << PgQuery.deparse_stmt(
        PgQuery::CreateStmt.new(
          **create_stmt.to_h,
          table_elts: [placeholder_column]
        )
      )
      table_str << ";"

      table_columns = create_stmt.table_elts.map do |elt|
        "\n    #{deparse_table_elt(elt)}"
      end.join(",")
      table_columns << "\n"

      table_str[deparse_table_elt(placeholder_column)] = table_columns

      table_str
    end

    def deparse_table_elt(elt)
      PgQuery.deparse_stmt(
        PgQuery::CreateStmt.new(
          relation: { relname: "tmp" }, table_elts: [elt]
        )
      ).gsub(/\ACREATE TABLE ONLY tmp \((.*)\)\z/, '\1')
    end
  end
end
