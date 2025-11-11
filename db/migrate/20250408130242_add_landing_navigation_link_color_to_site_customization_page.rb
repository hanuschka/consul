class AddLandingNavigationLinkColorToSiteCustomizationPage < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :landing_navigation_link_color, :string, default: "#000000"
  end
end
