class AddCreatedProjektIdsToProjektImports < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_imports, :created_projekt_ids, :integer, array: true, null: false, default: []
  end
end
