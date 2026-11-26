class AddImportedContentBlockTemplateIdsToProjekts < ActiveRecord::Migration[7.2]
  def change
    add_column :projekts, :imported_content_block_template_ids, :integer, array: true, default: [], null: false
  end
end
