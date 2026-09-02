class BackfillProjektSettingColumnsFromEav < ActiveRecord::Migration[6.1]
  KEY_TO_COLUMN = {
    "projekt_feature.main.activate" => "activated",
    "projekt_feature.general.show_in_navigation" => "show_in_navigation",
    "projekt_feature.general.show_in_overview_page" => "show_in_overview_page",
    "projekt_feature.general.show_in_overview_page_navigation" => "show_in_overview_page_navigation",
    "projekt_feature.general.show_in_homepage" => "show_in_homepage",
    "projekt_feature.general.show_in_individual_list" => "show_in_individual_list",
    "projekt_feature.general.show_in_sidebar_filter" => "show_in_sidebar_filter"
  }.freeze

  def up
    log_anomalous_values

    KEY_TO_COLUMN.each do |key, column|
      execute <<~SQL
        UPDATE projekts p
        SET #{column} = COALESCE(s.value IN ('active', 't'), false)
        FROM projekt_settings s
        WHERE s.projekt_id = p.id
          AND s.key = #{quote(key)}
      SQL
    end

    # projekt_settings stays authoritative for every other key, so a projekt
    # without a row would silently fall back to the column default.
    KEY_TO_COLUMN.each do |key, column|
      execute <<~SQL
        INSERT INTO projekt_settings (projekt_id, key, value, created_at, updated_at)
        SELECT p.id, #{quote(key)}, CASE WHEN p.#{column} THEN 'active' ELSE '' END, NOW(), NOW()
        FROM projekts p
        WHERE NOT EXISTS (
          SELECT 1 FROM projekt_settings s
          WHERE s.projekt_id = p.id AND s.key = #{quote(key)}
        )
      SQL
    end
  end

  def down
    KEY_TO_COLUMN.each do |key, column|
      execute <<~SQL
        UPDATE projekt_settings s
        SET value = CASE WHEN p.#{column} THEN 'active' ELSE '' END
        FROM projekts p
        WHERE s.projekt_id = p.id
          AND s.key = #{quote(key)}
      SQL
    end
  end

  private

    # A promoted value that is neither the legacy "on" nor "off" encoding
    # silently becomes false — log each one.
    def log_anomalous_values
      quoted_keys = KEY_TO_COLUMN.keys.map { |key| quote(key) }.join(", ")

      anomalies = select_all(<<~SQL)
        SELECT projekt_id, key, value
        FROM projekt_settings
        WHERE key IN (#{quoted_keys})
          AND value IS NOT NULL
          AND value NOT IN ('active', 't', '')
        ORDER BY key, projekt_id
      SQL

      anomalies.each do |row|
        say "anomalous value: projekt=#{row["projekt_id"]} #{row["key"]}=#{row["value"].inspect}"
      end
    end

    def quote(value)
      ActiveRecord::Base.connection.quote(value)
    end
end
