class AddContentLocaleToProjektImports < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_imports, :content_locale, :string
  end
end
