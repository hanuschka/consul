class AddProjektIdToContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_content_blocks, :projekt_id, :integer
  end
end
