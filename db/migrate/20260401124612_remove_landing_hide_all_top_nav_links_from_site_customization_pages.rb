class RemoveLandingHideAllTopNavLinksFromSiteCustomizationPages < ActiveRecord::Migration[6.1]
  def change
    remove_column :site_customization_pages, :landing_hide_all_top_nav_links, :boolean, default: false
    remove_column :site_customization_pages, :landing_show_projekts_overview, :boolean, default: true
  end
end
