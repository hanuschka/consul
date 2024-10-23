class ChanageTemporaryAuthTokenGeneratedAtInUsers < ActiveRecord::Migration[6.1]
  def change
    remove_column :users, :temporary_auth_token_generated_at
    add_column :users, :temporary_auth_token_valid_until, :datetime
  end
end
