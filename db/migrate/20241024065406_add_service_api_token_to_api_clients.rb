class AddServiceApiTokenToApiClients < ActiveRecord::Migration[6.1]
  def change
    add_column :api_clients, :service_api_token, :string
    add_index :api_clients, :service_api_token
  end
end
