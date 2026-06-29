class CreateMasterportalCollections < ActiveRecord::Migration[6.1]
  def change
    create_table :masterportal_collections do |t|
      t.references :projekt_phase, null: false, foreign_key: true, index: true
      t.string :collection_id, null: false
      t.string :name
      t.string :endpoint_url
      t.boolean :create_domain_records, null: false, default: false
      t.string :import_status, null: false, default: "pending"
      t.text :import_error
      t.datetime :last_imported_at
      t.integer :last_imported_count, null: false, default: 0
      t.string :destroy_status
      t.text :destroy_error

      t.timestamps
    end

    add_index :masterportal_collections, [:projekt_phase_id, :collection_id],
              unique: true, name: "index_masterportal_collections_on_phase_and_collection_id"
  end
end
