class AddSettingColumnsToProjekts < ActiveRecord::Migration[6.1]
  # Only the settings that SQL scopes filter on are promoted; the remaining
  # projekt settings stay in projekt_settings.
  BOOLEAN_COLUMNS = {
    activated: false,
    show_in_navigation: true,
    show_in_overview_page: true,
    show_in_overview_page_navigation: false,
    show_in_homepage: true,
    show_in_individual_list: false,
    show_in_sidebar_filter: true
  }.freeze

  def up
    BOOLEAN_COLUMNS.each do |column, default|
      add_column :projekts, column, :boolean, null: false, default: default
      add_index :projekts, column
    end
  end

  def down
    BOOLEAN_COLUMNS.keys.reverse_each do |column|
      remove_column :projekts, column
    end
  end
end
