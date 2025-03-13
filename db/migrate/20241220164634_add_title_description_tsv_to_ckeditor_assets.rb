class AddTitleDescriptionTsvToCkeditorAssets < ActiveRecord::Migration[6.1]
  def change
    add_column :ckeditor_assets, :title, :string, default: ""
    add_column :ckeditor_assets, :description, :string, default: ""
    add_column :ckeditor_assets, :tsv, :tsvector
    add_column :ckeditor_assets, :alt_text, :string, default: ""
  end
end
