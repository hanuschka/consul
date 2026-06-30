class AddLinkedPageIdToNavbarItems < ActiveRecord::Migration[6.1]
  def change
    add_column :navbar_items, :linked_page_id, :integer
    add_index :navbar_items, :linked_page_id
  end
end
