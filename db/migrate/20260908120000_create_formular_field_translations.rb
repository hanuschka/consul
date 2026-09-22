class CreateFormularFieldTranslations < ActiveRecord::Migration[6.1]
  def up
    create_table :formular_field_translations do |t|
      t.integer :formular_field_id, null: false
      t.string :locale, null: false
      t.timestamps null: false
      t.string :name
      t.text :description
    end

    add_index :formular_field_translations, :formular_field_id,
      name: "index_formular_field_translations_on_formular_field_id"
    add_index :formular_field_translations, :locale,
      name: "index_formular_field_translations_on_locale"
    add_index :formular_field_translations, [:formular_field_id, :locale],
      unique: true, name: "index_formular_field_translations_on_field_id_and_locale"

    execute <<~SQL
      INSERT INTO formular_field_translations
        (formular_field_id, locale, name, description, created_at, updated_at)
      SELECT id, 'de', name, description, created_at, updated_at
      FROM formular_fields
    SQL

    remove_column :formular_fields, :name
    remove_column :formular_fields, :description
  end

  def down
    add_column :formular_fields, :name, :string
    add_column :formular_fields, :description, :string

    execute <<~SQL
      UPDATE formular_fields AS fields
      SET name = translations.name,
          description = translations.description
      FROM formular_field_translations AS translations
      WHERE translations.formular_field_id = fields.id
        AND translations.locale = 'de'
    SQL

    add_index :formular_fields, [:name, :formular_id],
      unique: true, name: "index_formular_fields_on_name_and_formular_id"

    drop_table :formular_field_translations
  end
end
