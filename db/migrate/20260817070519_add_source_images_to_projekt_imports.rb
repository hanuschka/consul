class AddSourceImagesToProjektImports < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_imports, :source_images, :jsonb, default: [], null: false
  end
end
