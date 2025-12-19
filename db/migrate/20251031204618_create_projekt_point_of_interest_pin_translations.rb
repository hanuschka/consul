class CreateProjektPointOfInterestPinTranslations < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_point_of_interest_pin_translations do |t|
      t.bigint :projekt_point_of_interest_pin_id, null: false
      t.string :locale, null: false
      t.text :description

      t.timestamps
    end

    add_index :projekt_point_of_interest_pin_translations, :projekt_point_of_interest_pin_id, name: 'index_poi_pin_translations_on_poi_pin_id'
    add_index :projekt_point_of_interest_pin_translations, :locale
  end
end
