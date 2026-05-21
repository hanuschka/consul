class AddTrgmIndexesToMasterportalPins < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    add_index :masterportal_pins, :title,
      using: :gin, opclass: :gin_trgm_ops,
      name: "index_masterportal_pins_on_title_trgm",
      algorithm: :concurrently, if_not_exists: true

    add_index :masterportal_pins, :description,
      using: :gin, opclass: :gin_trgm_ops,
      name: "index_masterportal_pins_on_description_trgm",
      algorithm: :concurrently, if_not_exists: true

    add_index :masterportal_pins, :external_id,
      using: :gin, opclass: :gin_trgm_ops,
      name: "index_masterportal_pins_on_external_id_trgm",
      algorithm: :concurrently, if_not_exists: true

    add_index :masterportal_pins, :collection_id,
      using: :gin, opclass: :gin_trgm_ops,
      name: "index_masterportal_pins_on_collection_id_trgm",
      algorithm: :concurrently, if_not_exists: true

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
        index_masterportal_pins_on_properties_text_trgm
        ON masterportal_pins
        USING gin ((properties::text) gin_trgm_ops);
    SQL
  end

  def down
    remove_index :masterportal_pins, name: "index_masterportal_pins_on_title_trgm", if_exists: true
    remove_index :masterportal_pins, name: "index_masterportal_pins_on_description_trgm", if_exists: true
    remove_index :masterportal_pins, name: "index_masterportal_pins_on_external_id_trgm", if_exists: true
    remove_index :masterportal_pins, name: "index_masterportal_pins_on_collection_id_trgm", if_exists: true
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_masterportal_pins_on_properties_text_trgm;"
  end
end
