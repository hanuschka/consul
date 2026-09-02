class AddTitleImageChoiceToProjektImports < ActiveRecord::Migration[6.1]
  def up
    add_column :projekt_imports, :title_image_mode, :string, default: "document", null: false
    add_column :projekt_imports, :title_image_index, :integer

    execute <<~SQL.squish
      UPDATE projekt_imports SET title_image_mode = 'generated' WHERE generate_image = true
    SQL

    remove_column :projekt_imports, :generate_image
  end

  def down
    add_column :projekt_imports, :generate_image, :boolean, default: false, null: false

    execute <<~SQL.squish
      UPDATE projekt_imports SET generate_image = true WHERE title_image_mode = 'generated'
    SQL

    remove_column :projekt_imports, :title_image_index
    remove_column :projekt_imports, :title_image_mode
  end
end
