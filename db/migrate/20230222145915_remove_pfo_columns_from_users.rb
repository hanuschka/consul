class RemovePfoColumnsFromUsers < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :pfo_first_name, :string
    remove_column :users, :pfo_last_name, :string
    remove_column :users, :pfo_street_name, :string
    remove_column :users, :pfo_street_number, :string
    remove_column :users, :pfo_plz, :string
    remove_column :users, :pfo_city, :string
  end
end
