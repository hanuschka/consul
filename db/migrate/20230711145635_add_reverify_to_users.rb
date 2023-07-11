class AddReverifyToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :reverify, :boolean, default: true unless column_exists? :users, :reverify
  end
end
