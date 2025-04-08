class AddOverviewPageSettingToSiteCustomizationPages < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :landing_show_projekts_overview, :boolean, default: true
    add_column :site_customization_pages, :landing_site_logo_not_clickable, :boolean, default: false
  end
end
