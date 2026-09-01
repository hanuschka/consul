class AddCopyColumnsToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :copy_status, :string
    add_column :projekts, :copied_from_projekt_id, :bigint
    add_index :projekts, :copied_from_projekt_id
  end
end
