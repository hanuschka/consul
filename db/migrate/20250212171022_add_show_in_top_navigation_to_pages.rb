class AddShowInTopNavigationToPages < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :landing_show_in_top_nav, :boolean, default: false
    add_column :site_customization_pages, :landing_hide_all_top_nav_links, :boolean, default: false
    add_column :site_customization_pages, :landing_hide_title_and_subtitle, :boolean, default: false

    add_index :site_customization_pages, :landing_show_in_top_nav, name: "pages_landing_show_in_top_nav"
  end
end
