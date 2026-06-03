class AddGuestUserAgentToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :guest_user_agent, :string
  end
end
