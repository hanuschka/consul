class AddAccessLevelToApiClients < ActiveRecord::Migration[6.1]
  def change
    add_column :api_clients, :access_level, :string
  end
end

