class CreateMasterportalPins < ActiveRecord::Migration[6.1]
  def change
    create_table :masterportal_pins do |t|
      t.bigint :projekt_phase_id, null: false
      t.string :endpoint_url, null: false
      t.string :collection_id, null: false
      t.string :external_id, null: false
      t.string :title
      t.text :description
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.jsonb :properties, null: false, default: {}
      t.jsonb :raw_feature
      t.datetime :last_imported_at

      t.timestamps
    end

    add_index :masterportal_pins, :projekt_phase_id
    add_index :masterportal_pins, [:projekt_phase_id, :external_id], unique: true,
              name: "index_masterportal_pins_on_phase_and_external_id"
    add_index :masterportal_pins, [:projekt_phase_id, :collection_id],
              name: "index_masterportal_pins_on_phase_and_collection_id"
  end
end
