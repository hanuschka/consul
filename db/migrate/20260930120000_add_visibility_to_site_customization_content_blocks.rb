class AddVisibilityToSiteCustomizationContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_content_blocks, :visible, :boolean, default: true, null: false
    add_column :site_customization_content_blocks, :visible_from, :datetime
    add_column :site_customization_content_blocks, :visible_until, :datetime
  end
end
