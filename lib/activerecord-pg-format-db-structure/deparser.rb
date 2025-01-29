# frozen_string_literal: true

require "pg_query"
require "anbt-sql-formatter/formatter"

module ActiveRecordPgFormatDbStructure
  # Returns a list of SQL strings from a list of PgQuery::RawStmt.
  class Deparser
    attr_reader :source

    PRETTY_INDENT_STRING = "    "

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
      in stmt: { select_stmt: _ }
        deparse_query_statement(raw_statement.stmt.select_stmt)
      in stmt: { insert_stmt: _ }
        deparse_insert_statement(raw_statement.stmt.insert_stmt)
      in stmt: { create_table_as_stmt: _ }
        deparse_create_table_as_stmt(raw_statement.stmt.create_table_as_stmt)
      in stmt: { view_stmt: _ }
        deparse_view_stmt(raw_statement.stmt.view_stmt)
      else
        "\n#{deparse_stmt(raw_statement.stmt.inner)}"
      end
    end

    private

    def deparse_stmt(stmt)
      "\n#{PgQuery.deparse_stmt(stmt)};"
    end

    def deparse_query_statement(stmt)
      generic_query_str = +"\n\n"
      generic_query_str << pretty_formt_sql_string(PgQuery.deparse_stmt(stmt))
      generic_query_str << ";"
    end

    def deparse_index_stmt(index_stmt)
      deparse_stmt(index_stmt)
    end

    def deparse_alter_table_stmt(alter_table_stmt)
      alter_table_str = +"\n\n"
      alter_table_str << PgQuery.deparse_stmt(
        PgQuery::AlterTableStmt.new(
          **alter_table_stmt.to_h,
          cmds: []
        )
      ).chomp(" ")

      alter_table_cmds_str = alter_table_stmt.cmds.map do |cmd|
        "\n  #{deparse_alter_table_cmd(cmd)}"
      end.join(",")

      alter_table_str << alter_table_cmds_str
      alter_table_str << ";"
      alter_table_str
    end

    def deparse_alter_table_cmd(cmd)
      PgQuery.deparse_stmt(
        PgQuery::AlterTableStmt.new(
          relation: { relname: "tmp" },
          cmds: [cmd]
        )
      ).gsub("ALTER ONLY tmp ", "")
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

    def deparse_create_table_as_stmt(stmt)
      create_table_as_stmt_str = +"\n\n"
      create_table_as_stmt_str << PgQuery.deparse_stmt(
        PgQuery::CreateTableAsStmt.new(
          **stmt.to_h,
          query: PgQuery::Node.from(placeholder_query_stmt)
        )
      )
      create_table_as_stmt_str << ";"

      query_str = +"(\n"
      query_str << pretty_formt_sql_string(PgQuery.deparse_stmt(stmt.query.inner)).gsub(/^/, PRETTY_INDENT_STRING)
      query_str << "\n)"

      create_table_as_stmt_str[placeholder_query_string] = query_str
      create_table_as_stmt_str
    end

    def deparse_view_stmt(stmt)
      view_stmt_str = +"\n\n"
      view_stmt_str << PgQuery.deparse_stmt(
        PgQuery::ViewStmt.new(
          **stmt.to_h,
          query: PgQuery::Node.from(placeholder_query_stmt)
        )
      )
      view_stmt_str << ";"

      query_str = +"(\n"
      query_str << pretty_formt_sql_string(PgQuery.deparse_stmt(stmt.query.inner)).gsub(/^/, PRETTY_INDENT_STRING)
      query_str << "\n)"

      view_stmt_str[placeholder_query_string] = query_str
      view_stmt_str
    end

    def deparse_insert_statement(insert_stmt)
      insert_stmt_str = +"\n\n\n"
      insert_stmt_str << PgQuery.deparse_stmt(
        PgQuery::InsertStmt.new(
          **insert_stmt.to_h,
          select_stmt: PgQuery::Node.from(placeholder_query_stmt)
        )
      )
      insert_stmt_str << "\n;"

      query_str = pretty_formt_sql_string(PgQuery.deparse_stmt(insert_stmt.select_stmt.inner))
      query_str.gsub!("VALUES (", "VALUES\n (")

      insert_stmt_str[placeholder_query_string] = query_str
      insert_stmt_str
    end

    def pretty_formt_sql_string(sql)
      rule = AnbtSql::Rule.new
      rule.keyword = AnbtSql::Rule::KEYWORD_UPPER_CASE
      rule.indent_string = PRETTY_INDENT_STRING
      formatter = AnbtSql::Formatter.new(rule)
      formatter.format(sql)
    end

    def placeholder_query_string
      @placeholder_query_string ||= PgQuery.deparse_stmt(placeholder_query_stmt)
    end

    def placeholder_query_stmt
      @placeholder_query_stmt ||= PgQuery.parse("SELECT placeholder").tree.stmts.first.stmt.select_stmt
    end
  end
end
