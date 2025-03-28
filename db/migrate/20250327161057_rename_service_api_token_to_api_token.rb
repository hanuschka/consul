class RenameServiceApiTokenToApiToken < ActiveRecord::Migration[6.1]
  def change
    rename_column :api_clients, :service_api_token, :service_auth_token
    rename_column :api_clients, :auth_token, :consul_auth_token
  end
end
