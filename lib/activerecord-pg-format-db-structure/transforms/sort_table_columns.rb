# frozen_string_literal: true

require_relative "base"

module ActiveRecordPgFormatDbStructure
  module Transforms
    # Sort table columns
    class SortTableColumns < Base
      SORTABLE_ENTRY = Data.define(
        :name,
        :is_column,
        :is_constraint,
        :is_primary_key,
        :is_foreign_key,
        :is_timestamp,
        :raw_entry
      )

      class << self
        attr_accessor :priority_mapping
      end

      self.priority_mapping = lambda do |sortable_entry|
        case sortable_entry
        in is_column: true, is_primary_key: true, name:
          [0, name]
        in is_column: true, is_foreign_key: true, name:
          [1, name]
        in is_column: true, is_timestamp: false, name:
          [2, name]
        in is_column: true, is_timestamp: true, name:
          [3, name]
        in is_constraint: true, name:
          [5, name]
          # :nocov:
          # non-reachable else
          # :nocov:
        end
      end

      def transform!
        foreign_keys = extract_foreign_keys
        primary_keys = extract_primary_keys
        raw_statements.each do |raw_statement|
          next unless raw_statement.stmt.to_h in create_stmt: { relation: { schemaname:, relname: } }

          raw_statement.stmt.create_stmt.table_elts.sort_by! do |table_elt|
            elt_priority(
              table_elt:,
              primary_keys: primary_keys.fetch({ schemaname:, relname: }, Set.new),
              foreign_keys: foreign_keys.fetch({ schemaname:, relname: }, Set.new)
            )
          end
        end
      end

      private

      def extract_primary_keys
        primary_keys = {}
        raw_statements.each do |raw_statement|
          case raw_statement.stmt.to_h
          in alter_table_stmt: {
            objtype: :OBJECT_TABLE,
            relation: {
              schemaname:,
              relname:
            }
          }
            primary_keys[{ schemaname:, relname: }] ||= Set.new
            raw_statement.stmt.alter_table_stmt.cmds.each do |cmd|
              extract_primary_keys_from_alter_table_cmd(cmd:).each do |key|
                primary_keys[{ schemaname:, relname: }] << key
              end
            end
          in create_stmt: { relation: { schemaname:, relname: } }
            primary_keys[{ schemaname:, relname: }] ||= Set.new
            raw_statement.stmt.create_stmt.table_elts.each do |table_elt|
              extract_primary_keys_from_table_elt(table_elt:).each do |key|
                primary_keys[{ schemaname:, relname: }] << key
              end
            end
          else
          end
        end
        primary_keys
      end

      def extract_primary_keys_from_alter_table_cmd(cmd:)
        if cmd.to_h in {
          alter_table_cmd: {
            subtype: :AT_AddConstraint,
            def: {
              constraint: {
                contype: :CONSTR_PRIMARY
              }
            }
          }
        }
          cmd.alter_table_cmd.def.constraint.keys.map do |key|
            key.string.sval
          end
        else
          []
        end
      end

      def extract_primary_keys_from_table_elt(table_elt:)
        case table_elt.to_h
        in column_def: { constraints: [*, {constraint: {contype: :CONSTR_PRIMARY}}, *] }
          [table_elt.column_def.colname]
        in constraint: { contype: :CONSTR_PRIMARY }
          table_elt.constraint.keys.map do |key|
            key.string.sval
          end
        else
          []
        end
      end

      def extract_foreign_keys
        foreign_keys = {}
        raw_statements.each do |raw_statement|
          case raw_statement.stmt.to_h
          in alter_table_stmt: {
            objtype: :OBJECT_TABLE,
            relation: {
              schemaname:,
              relname:
            }
          }
            foreign_keys[{ schemaname:, relname: }] ||= Set.new
            raw_statement.stmt.alter_table_stmt.cmds.each do |cmd|
              extract_foreign_keys_from_alter_table_cmd(cmd:).each do |key|
                foreign_keys[{ schemaname:, relname: }] << key
              end
            end
          in create_stmt: { relation: { schemaname:, relname: } }
            foreign_keys[{ schemaname:, relname: }] ||= Set.new
            raw_statement.stmt.create_stmt.table_elts.each do |table_elt|
              extract_foreign_keys_from_table_elt(table_elt:).each do |key|
                foreign_keys[{ schemaname:, relname: }] << key
              end
            end
          else
          end
        end
        foreign_keys
      end

      def extract_foreign_keys_from_alter_table_cmd(cmd:)
        if cmd.to_h in {
          alter_table_cmd: {
            subtype: :AT_AddConstraint,
            def: {
              constraint: {
                contype: :CONSTR_FOREIGN
              }
            }
          }
        }
          cmd.alter_table_cmd.def.constraint.fk_attrs.map do |fk_attr|
            fk_attr.string.sval
          end
        else
          []
        end
      end

      def extract_foreign_keys_from_table_elt(table_elt:)
        case table_elt.to_h
        in column_def: { constraints: [*, {constraint: {contype: :CONSTR_FOREIGN}}, *] }
          [table_elt.column_def.colname]
        in constraint: { contype: :CONSTR_FOREIGN }
          table_elt.constraint.fk_attrs.map do |fk_attr|
            fk_attr.string.sval
          end
        else
          []
        end
      end

      def elt_priority(table_elt:, primary_keys:, foreign_keys:)
        case table_elt.to_h
        in column_def: _
          self.class.priority_mapping[
            SORTABLE_ENTRY.new(
              name: table_elt.column_def.colname,
              is_column: true,
              is_constraint: false,
              is_primary_key: primary_keys.include?(table_elt.column_def.colname),
              is_timestamp: timestamp?(table_elt.column_def),
              is_foreign_key: foreign_keys.include?(table_elt.column_def.colname),
              raw_entry: table_elt
            )
          ]
        in constraint: _
          self.class.priority_mapping[
            SORTABLE_ENTRY.new(
              name: table_elt.constraint.conname,
              is_column: false,
              is_constraint: true,
              is_primary_key: false,
              is_timestamp: false,
              is_foreign_key: false,
              raw_entry: table_elt
            )
          ]
          # :nocov:
          # non-reachable else
          # :nocov:
        end
      end

      def timestamp?(table_elt)
        table_elt.type_name.names.any? { |name| name.to_h in string: { sval: "timestamp" } }
      end
    end
  end
end
