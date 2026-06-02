class AddSingleSystemUserIndexToUsers < ActiveRecord::Migration[6.1]
  def change
    add_index :users, :system_user, unique: true, where: '"system_user" = true',
              name: "index_users_on_single_system_user"
  end
end
