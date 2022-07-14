class AddPfoAddressToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :pfo_first_name, :string
    add_column :users, :pfo_last_name, :string
    add_column :users, :pfo_street_name, :string
    add_column :users, :pfo_street_number, :string
    add_column :users, :pfo_plz, :string
    add_column :users, :pfo_city, :string
  end
end
