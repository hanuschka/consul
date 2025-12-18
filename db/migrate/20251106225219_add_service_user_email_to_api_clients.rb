class AddServiceUserEmailToApiClients < ActiveRecord::Migration[6.1]
  def change
    add_column :api_clients, :service_user_email, :string, index: true
  end
end
