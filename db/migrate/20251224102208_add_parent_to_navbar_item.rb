class AddParentToNavbarItem < ActiveRecord::Migration[6.1]
  def change
    add_reference :navbar_items, :parent, foreign_key: { to_table: :navbar_items }, index: true
    add_column :navbar_items, :position, :integer, default: 0, null: false
  end
end
