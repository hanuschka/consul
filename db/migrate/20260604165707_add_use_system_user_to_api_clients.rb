class AddUseSystemUserToApiClients < ActiveRecord::Migration[6.1]
  def up
    add_column :api_clients, :use_system_user, :boolean, default: true, null: false

    execute <<~SQL
      UPDATE api_clients
      SET use_system_user = FALSE
      WHERE id IN (SELECT api_client_id FROM users WHERE api_client_id IS NOT NULL)
    SQL
  end

  def down
    remove_column :api_clients, :use_system_user
  end
end
