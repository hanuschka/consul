class AddGuestToUsers < ActiveRecord::Migration[6.1]
  def change
    unless column_exists? :users, :guest
      add_column :users, :guest, :boolean, default: false
    end
  end
end
