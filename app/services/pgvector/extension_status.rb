# Whether the database behind this instance can store embeddings. Reported for
# provisioning rather than for a running feature: nothing in the app declares a
# vector column yet, so the check answers "would CREATE EXTENSION work here"
# ahead of the first migration that needs it.
#
# The two negative states are kept apart on purpose. An extension absent from
# pg_available_extensions has no control file on disk and needs an apt package
# on the database host; one that is available but not created only needs the
# statement. A single boolean would send an operator to the wrong fix.
module Pgvector::ExtensionStatus
  # pgvector names its type after the extension, so the same string identifies
  # both the extension to create and the column type to look for.
  EXTENSION_NAME = "vector".freeze

  CREATE_COMMAND = "CREATE EXTENSION vector;".freeze

  # pgvector ships as a per-server-version package, so the major version has to
  # come from the running server instead of being hardcoded.
  APT_COMMAND_TEMPLATE = "sudo apt-get install -y postgresql-%<major_version>s-pgvector  " \
                         "# then: CREATE EXTENSION vector;".freeze

  # The two index access methods pgvector adds. A vector column without one of
  # them is a sequential scan on every similarity query, which is why the
  # report lists indexes per column rather than only the columns.
  INDEX_METHODS = %w[hnsw ivfflat].freeze

  BLANK_REPORT = {
    checked: true,
    available: false,
    installed: false,
    version: nil,
    available_version: nil,
    vector_columns: [],
    install_command: nil
  }.freeze

  def self.report
    availability = availability_row

    return BLANK_REPORT.merge(install_command: apt_command) if availability.blank?

    installed_version = availability["installed_version"].presence

    BLANK_REPORT.merge(
      available: true,
      installed: installed_version.present?,
      version: installed_version,
      available_version: availability["default_version"].presence,
      vector_columns: installed_version.present? ? vector_columns : [],
      install_command: installed_version.present? ? nil : CREATE_COMMAND
    )
  rescue StandardError => error
    BLANK_REPORT.merge(checked: false, available: nil, error: error.message)
  end

  def self.availability_row
    connection.select_one(<<~SQL.squish)
      SELECT default_version, installed_version
      FROM pg_available_extensions
      WHERE name = #{connection.quote(EXTENSION_NAME)}
    SQL
  end

  def self.vector_columns
    indexes_by_column = vector_indexes

    column_rows.map do |row|
      {
        table: row["table_name"],
        column: row["column_name"],
        type: row["column_type"],
        indexes: indexes_by_column.fetch([row["table_name"], row["column_name"]], [])
      }
    end
  end

  def self.column_rows
    connection.select_all(<<~SQL.squish)
      SELECT c.relname AS table_name,
             a.attname AS column_name,
             format_type(a.atttypid, a.atttypmod) AS column_type
      FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_type t ON t.oid = a.atttypid
      WHERE t.typname = #{connection.quote(EXTENSION_NAME)}
        AND a.attnum > 0
        AND NOT a.attisdropped
        AND c.relkind = 'r'
        AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      ORDER BY c.relname, a.attname
    SQL
  end

  # Vector indexes are single-column, so the first entry of indkey identifies
  # the column the index belongs to. int2vector subscripts start at zero.
  def self.vector_indexes
    rows = connection.select_all(<<~SQL.squish)
      SELECT c.relname AS table_name,
             a.attname AS column_name,
             i.relname AS index_name,
             am.amname AS method
      FROM pg_index x
      JOIN pg_class c ON c.oid = x.indrelid
      JOIN pg_class i ON i.oid = x.indexrelid
      JOIN pg_am am ON am.oid = i.relam
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = x.indkey[0]
      WHERE am.amname IN (#{quoted_index_methods})
      ORDER BY i.relname
    SQL

    grouped_rows = rows.group_by { |row| [row["table_name"], row["column_name"]] }

    grouped_rows.transform_values do |index_rows|
      index_rows.map { |row| { name: row["index_name"], method: row["method"] } }
    end
  end

  def self.quoted_index_methods
    INDEX_METHODS.map { |method| connection.quote(method) }.join(", ")
  end

  def self.apt_command
    format(APT_COMMAND_TEMPLATE, major_version: server_major_version)
  end

  def self.server_major_version
    connection.select_value("SELECT current_setting('server_version_num')").to_i / 10_000
  end

  def self.connection
    ActiveRecord::Base.connection
  end
end
