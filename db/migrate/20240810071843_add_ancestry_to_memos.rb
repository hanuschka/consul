class AddAncestryToMemos < ActiveRecord::Migration[6.1]
  def change
    add_column :memos, :ancestry, :string
    add_index :memos, :ancestry
  end
end
