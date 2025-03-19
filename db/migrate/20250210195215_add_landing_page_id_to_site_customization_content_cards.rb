class AddLandingPageIdToSiteCustomizationContentCards < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_content_cards, :landing_page_id, :integer
    add_index :site_customization_content_cards, :landing_page_id
  end
end
