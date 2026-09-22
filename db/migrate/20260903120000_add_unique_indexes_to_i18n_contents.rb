class AddUniqueIndexesToI18nContents < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE i18n_content_translations t
      SET i18n_content_id = c.canonical_id
      FROM (
        SELECT id, MIN(id) OVER (PARTITION BY "key") AS canonical_id
        FROM i18n_contents
        WHERE "key" IS NOT NULL
      ) c
      WHERE t.i18n_content_id = c.id AND c.id <> c.canonical_id
    SQL

    execute <<~SQL
      DELETE FROM i18n_contents
      WHERE "key" IS NOT NULL
        AND id NOT IN (
          SELECT MIN(id) FROM i18n_contents WHERE "key" IS NOT NULL GROUP BY "key"
        )
    SQL

    execute <<~SQL
      DELETE FROM i18n_content_translations
      WHERE id NOT IN (
        SELECT MIN(id) FROM i18n_content_translations GROUP BY i18n_content_id, locale
      )
    SQL

    add_index :i18n_contents, :key, unique: true
    add_index :i18n_content_translations, [:i18n_content_id, :locale],
              unique: true,
              name: "index_i18n_content_translations_on_content_and_locale"
  end

  def down
    remove_index :i18n_contents, :key
    remove_index :i18n_content_translations,
                 name: "index_i18n_content_translations_on_content_and_locale"
  end
end
