class CreateNewApiClients < ActiveRecord::Migration[6.1]
  def change
    create_table :api_clients do |t|
      t.string :name
      t.string :access_level
      t.string :service_user_email
      t.string :access_token, unique: true

      t.timestamps
    end
  end
end
