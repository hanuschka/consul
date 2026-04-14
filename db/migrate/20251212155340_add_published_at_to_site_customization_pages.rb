class AddPublishedAtToSiteCustomizationPages < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :published_at, :datetime
  end
end
