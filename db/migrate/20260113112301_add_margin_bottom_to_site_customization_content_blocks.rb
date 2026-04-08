class AddMarginBottomToSiteCustomizationContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_content_blocks, :margin_bottom, :boolean, default: false, null: false
  end
end
