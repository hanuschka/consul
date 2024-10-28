class AddNewContentBlockModeToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :new_content_block_mode, :boolean
  end
end
