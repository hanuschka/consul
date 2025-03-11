class AddLandingToSiteCustomizationPages < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :landing, :boolean, default: false
    remove_column :site_customization_pages, :type
  end
end
