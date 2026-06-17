class AddUserIdToAdminImages < ActiveRecord::Migration[6.1]
  def change
    add_column :admin_images, :user_id, :bigint
    add_index :admin_images, :user_id
  end
end
