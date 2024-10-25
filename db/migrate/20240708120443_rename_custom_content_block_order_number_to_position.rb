class RenameCustomContentBlockOrderNumberToPosition < ActiveRecord::Migration[6.1]
  def change
    rename_column :site_customization_content_blocks, :order_number, :position
  end
end
