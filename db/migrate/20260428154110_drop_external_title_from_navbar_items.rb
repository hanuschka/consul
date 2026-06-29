class DropExternalTitleFromNavbarItems < ActiveRecord::Migration[6.1]
  def up
    NavbarItem.where(kind: NavbarItem.kinds[:external])
      .where(custom_title: [nil, ""])
      .where.not(external_title: [nil, ""])
      .update_all("custom_title = external_title")

    remove_column :navbar_items, :external_title
  end

  def down
    add_column :navbar_items, :external_title, :string
  end
end
