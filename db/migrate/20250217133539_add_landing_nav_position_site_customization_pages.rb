class AddLandingNavPositionSiteCustomizationPages < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :landing_nav_position, :integer
  end
end
