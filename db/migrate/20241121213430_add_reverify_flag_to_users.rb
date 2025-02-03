class AddReverifyFlagToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :reverify, :boolean, default: true unless column_exists? :users, :reverify
  end
end
