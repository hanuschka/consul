class AddInstanceConfigurationAccessToApiClients < ActiveRecord::Migration[7.2]
  def change
    add_column :api_clients, :instance_configuration_access, :boolean, default: false, null: false
  end
end
