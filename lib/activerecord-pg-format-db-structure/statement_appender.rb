# frozen_string_literal: true

require "pg_query"
require_relative "indenter"

module ActiveRecordPgFormatDbStructure
  # Appends statements with reasonable spacing in-between
  class StatementAppender
    attr_reader :output

    def initialize(output = +"")
      @output = output
      @previous_statement_kind = nil
    end

    def append_statement!(statement, statement_kind:)
      output.chomp!
      output << newlines_separator(
        previous_kind: @previous_statement_kind,
        current_kind: statement_kind
      )
      @previous_statement_kind = statement_kind
      output << statement
      output << "\n"
    end

    private

    def newlines_separator(previous_kind:, current_kind:)
      case [
        previous_kind,
        current_kind
      ]
      in [
        nil,
        _
      ]
        ""
      in [
        _,
        :insert_stmt | :create_stmt | :view_stmt | :create_table_as_stmt
      ]
        "\n\n\n"
      in [
        :create_stmt | :view_stmt | :create_table_as_stmt | :index_stmt,
        :index_stmt
      ] | [
        :variable_set_stmt,
        :variable_set_stmt
      ]
        "\n"
      else
        "\n\n"
      end
    end
  end
end
