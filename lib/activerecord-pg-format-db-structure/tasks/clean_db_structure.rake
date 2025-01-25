# frozen_string_literal: true

require_relative "../formatter"

Rake::Task["db:schema:dump"].enhance do
  formatter = ActiveRecordPgFormatDbStructure::Formatter.new(
    **Rails.application.config.activerecord_pg_format_db_structure
  )

  ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).each do |db_config|
    filename = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(db_config, :sql)
    next unless File.exist?(filename)

    formatted = formatter.format(File.read(filename))
    File.write(filename, formatted)
  end
end
