class ChangeMarginBottomToIntegerInContentBlocks < ActiveRecord::Migration[6.1]
  def change
    remove_column :site_customization_content_blocks, :margin_bottom, :boolean
    add_column :site_customization_content_blocks, :margin_bottom, :integer
  end
end
