class CreateApiClients < ActiveRecord::Migration[5.2]
  def change
    create_table :api_clients do |t|
      t.string :name
      t.integer :registration_status
      t.string :auth_token, unique: true
      t.string :domain, unique: true
      t.timestamps
    end
  end
end
