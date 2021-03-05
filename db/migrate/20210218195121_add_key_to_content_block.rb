class AddKeyToContentBlock < ActiveRecord::Migration[5.1]
  def change
    add_column :site_customization_content_blocks, :key, :string
    remove_index :site_customization_content_blocks, name: :index_site_customization_content_blocks_on_name_and_locale
    add_index :site_customization_content_blocks, [:key, :name, :locale], unique: true, name: :locale_key_name_index
  end
end
