class AddApiClientToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :api_client_id, :integer, index: true
  end
end
