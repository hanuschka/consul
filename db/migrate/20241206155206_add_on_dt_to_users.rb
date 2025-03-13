class AddOnDtToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :on_dt, :boolean, default: false
  end
end
