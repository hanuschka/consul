class AddSystemUserToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :system_user, :boolean, default: false, null: false
  end
end
