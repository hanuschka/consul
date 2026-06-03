class AddImportedByAiToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :imported_by_ai, :boolean, null: false, default: false
    add_index :projekts, :imported_by_ai
  end
end
