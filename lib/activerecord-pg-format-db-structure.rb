# frozen_string_literal: true

require_relative "activerecord-pg-format-db-structure/version"

require_relative "activerecord-pg-format-db-structure/deparser"
require_relative "activerecord-pg-format-db-structure/preprocessors/remove_whitespaces"
require_relative "activerecord-pg-format-db-structure/transforms/remove_comments_on_extensions"
require_relative "activerecord-pg-format-db-structure/transforms/inline_serials"
require_relative "activerecord-pg-format-db-structure/transforms/inline_primary_keys"
require_relative "activerecord-pg-format-db-structure/transforms/inline_foreign_keys"
require_relative "activerecord-pg-format-db-structure/transforms/move_indices_after_create_table"
require_relative "activerecord-pg-format-db-structure/transforms/inline_constraints"
require_relative "activerecord-pg-format-db-structure/transforms/group_alter_table_statements"

module ActiveRecordPgFormatDbStructure
  DEFAULT_PREPROCESSORS = [
    Preprocessors::RemoveWhitespaces
  ].freeze

  DEFAULT_TRANSFORMS = [
    Transforms::RemoveCommentsOnExtensions,
    Transforms::InlinePrimaryKeys,
    # Transforms::InlineForeignKeys,
    Transforms::InlineSerials,
    Transforms::InlineConstraints,
    Transforms::MoveIndicesAfterCreateTable,
    Transforms::GroupAlterTableStatements
  ].freeze

  DEFAULT_DEPARSER = Deparser
end

# :nocov:
require_relative "activerecord-pg-format-db-structure/railtie" if defined?(Rails)
# :nocov:
