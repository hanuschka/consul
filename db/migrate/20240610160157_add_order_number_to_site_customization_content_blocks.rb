class AddOrderNumberToSiteCustomizationContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_content_blocks, :order_number, :integer, index: true
  end
end
