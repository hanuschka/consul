class AddShowInUsersOverviewToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :show_in_users_overview, :boolean, default: true
  end
end
