# frozen_string_literal: true

require "pg_query"

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
        deparse_select_stmt(raw_statement.stmt.select_stmt)
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

    def deparse_select_stmt(select_stmt)
      generic_query_str = +"\n\n"
      generic_query_str << deparse_leaf_select_stmt(select_stmt)
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
      ).gsub(/\AALTER ONLY tmp /, "")
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
      query_str << deparse_leaf_select_stmt(stmt.query.select_stmt).gsub(/^/, PRETTY_INDENT_STRING)
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
      query_str << deparse_leaf_select_stmt(stmt.query.select_stmt).gsub(/^/, PRETTY_INDENT_STRING)
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

      query_str = if insert_stmt.select_stmt.inner.values_lists.any?
                    deparse_values_list_select_stmt(insert_stmt.select_stmt.inner)
                  else
                    deparse_leaf_select_stmt(insert_stmt.select_stmt.inner)
                  end

      insert_stmt_str[placeholder_query_string] = query_str
      insert_stmt_str
    end

    def deparse_values_list_select_stmt(select_stmt)
      values_str = +"VALUES\n "
      values_str << select_stmt.values_lists.map do |values_list|
        PgQuery.deparse_stmt(PgQuery::SelectStmt.new(values_lists: [values_list])).gsub(/\AVALUES /, "")
      end.join("\n,")
      values_str
    end

    def deparse_leaf_select_stmt(select_stmt) # rubocop:disable Metrics/PerceivedComplexity
      target_list_placeholder = PgQuery::ResTarget.new(
        val: { a_const: { sval: { sval: "target_list_placeholder" } } }
      )

      if select_stmt.with_clause
        placeholder_with_clause = PgQuery::WithClause.new(
          **select_stmt.with_clause.to_h,
          ctes: select_stmt.with_clause.ctes.map do |cte|
            PgQuery::Node.from(
              PgQuery::CommonTableExpr.new(
                **cte.inner.to_h,
                ctequery: PgQuery::Node.from(placeholder_query_stmt("placeholder_for_#{cte.inner.ctename}_cte"))
              )
            )
          end
        )
      end

      select_stmt_str = PgQuery.deparse_stmt(
        PgQuery::SelectStmt.new(
          **select_stmt.to_h,
          with_clause: placeholder_with_clause,
          target_list: ([PgQuery::Node.from(target_list_placeholder)] if select_stmt.target_list.any?)
        )
      )

      if select_stmt.target_list.any?
        target_list_str = +"\n"
        target_list_str << select_stmt.target_list.map do |target|
          deparse_res_target(target.inner).gsub(/^/, PRETTY_INDENT_STRING)
        end.join(",\n")
        target_list_str << "\n"

        select_stmt_str[deparse_res_target(target_list_placeholder)] = target_list_str
      end

      select_stmt.with_clause&.ctes&.each do |cte|
        cte_str = +"\n"
        cte_str << deparse_leaf_select_stmt(cte.inner.ctequery.inner).gsub(/^/, PRETTY_INDENT_STRING)
        cte_str << "\n"

        select_stmt_str["SELECT placeholder_for_#{cte.inner.ctename}_cte"] = cte_str
      end

      select_stmt_str.gsub!(/ +$/, "")

      select_stmt_str
    end

    def deparse_res_target(res_target)
      PgQuery.deparse_stmt(
        PgQuery::SelectStmt.new(target_list: [PgQuery::Node.from(res_target)])
      ).gsub(/\ASELECT /, "")
    end

    def placeholder_query_string(placeholder_name = "placeholder")
      PgQuery.deparse_stmt(placeholder_query_stmt(placeholder_name))
    end

    def placeholder_query_stmt(placeholder_name = "placeholder")
      PgQuery.parse("SELECT #{placeholder_name}").tree.stmts.first.stmt.select_stmt
    end
  end
end
