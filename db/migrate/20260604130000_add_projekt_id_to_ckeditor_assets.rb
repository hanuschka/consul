class AddProjektIdToCkeditorAssets < ActiveRecord::Migration[6.1]
  def change
    add_column :ckeditor_assets, :projekt_id, :bigint
    add_index :ckeditor_assets, :projekt_id
  end
end
