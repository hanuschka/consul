class AddCustomTitleToNavbarItems < ActiveRecord::Migration[6.1]
  def change
    add_column :navbar_items, :custom_title, :string
  end
end
