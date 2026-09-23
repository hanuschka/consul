class AddSourceToProjektImports < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_imports, :source_kind, :string, null: false, default: "file"
    add_column :projekt_imports, :source_url, :string
    add_column :projekt_imports, :source_overlay, :jsonb, null: false, default: {}

    add_index :projekt_imports, :source_kind
  end
end
