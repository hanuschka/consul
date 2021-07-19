class AddPlzToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :plz, :string
  end
end
