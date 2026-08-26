class CreateSiteCustomizationContentBlockTranslations < ActiveRecord::Migration[6.1]
  def up
    create_table :site_customization_content_block_translations do |t|
      t.integer :site_customization_content_block_id, null: false
      t.string :locale, null: false
      t.timestamps null: false
      t.text :body
    end

    add_index :site_customization_content_block_translations,
      :site_customization_content_block_id, name: "index_scb_translations_on_content_block_id"
    add_index :site_customization_content_block_translations,
      :locale, name: "index_scb_translations_on_locale"
    add_index :site_customization_content_block_translations,
      [:site_customization_content_block_id, :locale],
      unique: true, name: "index_scb_translations_on_content_block_id_and_locale"

    execute <<~SQL
      INSERT INTO site_customization_content_block_translations
        (site_customization_content_block_id, locale, body, created_at, updated_at)
      SELECT id, COALESCE(NULLIF(locale, ''), 'de'), body, created_at, updated_at
      FROM site_customization_content_blocks
      WHERE body IS NOT NULL AND body <> ''
    SQL

    remove_column :site_customization_content_blocks, :body
  end

  def down
    add_column :site_customization_content_blocks, :body, :text

    execute <<~SQL
      UPDATE site_customization_content_blocks AS blocks
      SET body = translations.body
      FROM site_customization_content_block_translations AS translations
      WHERE translations.site_customization_content_block_id = blocks.id
        AND translations.locale = COALESCE(NULLIF(blocks.locale, ''), 'de')
    SQL

    drop_table :site_customization_content_block_translations
  end
end
