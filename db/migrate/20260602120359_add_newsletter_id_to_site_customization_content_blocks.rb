class AddNewsletterIdToSiteCustomizationContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_content_blocks, :newsletter_id, :integer
    add_index :site_customization_content_blocks, :newsletter_id
  end
end
