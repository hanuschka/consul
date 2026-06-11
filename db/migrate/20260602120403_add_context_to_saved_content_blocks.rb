class AddContextToSavedContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_column :saved_content_blocks, :context, :string, null: false, default: "projekt"
    add_index :saved_content_blocks, :context
  end
end
