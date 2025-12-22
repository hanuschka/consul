class AddUserIdToSavedContentBlocks < ActiveRecord::Migration[6.1]
  def change
    add_reference :saved_content_blocks, :user, foreign_key: true
  end
end
