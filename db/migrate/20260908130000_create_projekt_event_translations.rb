class CreateProjektEventTranslations < ActiveRecord::Migration[6.1]
  def up
    create_table :projekt_event_translations do |t|
      t.integer :projekt_event_id, null: false
      t.string :locale, null: false
      t.timestamps null: false
      t.string :title
      t.text :description
      t.string :location
    end

    add_index :projekt_event_translations, :projekt_event_id,
      name: "index_projekt_event_translations_on_projekt_event_id"
    add_index :projekt_event_translations, :locale,
      name: "index_projekt_event_translations_on_locale"
    add_index :projekt_event_translations, [:projekt_event_id, :locale],
      unique: true, name: "index_projekt_event_translations_on_event_id_and_locale"

    execute <<~SQL
      INSERT INTO projekt_event_translations
        (projekt_event_id, locale, title, description, location, created_at, updated_at)
      SELECT id, 'de', title, description, location, created_at, updated_at
      FROM projekt_events
    SQL

    remove_column :projekt_events, :title
    remove_column :projekt_events, :description
    remove_column :projekt_events, :location
  end

  def down
    add_column :projekt_events, :title, :string
    add_column :projekt_events, :description, :text
    add_column :projekt_events, :location, :string

    execute <<~SQL
      UPDATE projekt_events AS events
      SET title = translations.title,
          description = translations.description,
          location = translations.location
      FROM projekt_event_translations AS translations
      WHERE translations.projekt_event_id = events.id
        AND translations.locale = 'de'
    SQL

    drop_table :projekt_event_translations
  end
end
