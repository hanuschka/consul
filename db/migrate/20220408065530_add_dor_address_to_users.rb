class AddDorAddressToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :dor_first_name, :string
    add_column :users, :dor_last_name, :string
    add_column :users, :dor_street_name, :string
    add_column :users, :dor_street_number, :string
    add_column :users, :dor_plz, :string
    add_column :users, :dor_city, :string
  end
end
