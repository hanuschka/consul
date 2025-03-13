class AddTypeToSiteCustomizationPages < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :type, :string
    add_index :site_customization_pages, :type
  end
end
