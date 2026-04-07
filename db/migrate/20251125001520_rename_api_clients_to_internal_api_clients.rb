class RenameApiClientsToInternalApiClients < ActiveRecord::Migration[6.1]
  def change
    rename_table :api_clients, :internal_api_clients

    remove_column :internal_api_clients, :access_level
    remove_column :internal_api_clients, :service_user_email
  end
end
