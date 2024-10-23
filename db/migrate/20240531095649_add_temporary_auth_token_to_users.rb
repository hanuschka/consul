class AddTemporaryAuthTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :temporary_auth_token, :string
    add_column :users, :temporary_auth_token_generated_at, :datetime
  end
end
