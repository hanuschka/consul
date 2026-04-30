class AddOpenInNewTabToNavbarItems < ActiveRecord::Migration[6.1]
  def up
    add_column :navbar_items, :open_in_new_tab, :boolean, default: false, null: false

    NavbarItem.where(kind: NavbarItem.kinds[:external]).update_all(open_in_new_tab: true)
  end

  def down
    remove_column :navbar_items, :open_in_new_tab
  end
end
