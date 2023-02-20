class RemoveDorSpecificFieldsFromUsers < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :dor_first_name, :string
    remove_column :users, :dor_last_name, :string
    remove_column :users, :dor_street_name, :string
    remove_column :users, :dor_street_number, :string
    remove_column :users, :dor_plz, :string
    remove_column :users, :dor_city, :string
  end
end
