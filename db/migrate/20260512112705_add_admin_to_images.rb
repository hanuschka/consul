class AddAdminToImages < ActiveRecord::Migration[6.1]
  def change
    add_column :images, :admin, :boolean, default: false, null: false
  end
end
