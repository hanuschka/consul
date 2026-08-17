class BackfillMasterportalCollectionColorFlags < ActiveRecord::Migration[6.1]
  def up
    execute(<<~SQL)
      UPDATE masterportal_collections
      SET contains_shapes = TRUE
      WHERE EXISTS (
        SELECT 1 FROM masterportal_pins
        WHERE masterportal_pins.masterportal_collection_id = masterportal_collections.id
          AND masterportal_pins.geometry ->> 'type' IN ('Polygon', 'MultiPolygon')
      )
    SQL

    execute(<<~SQL)
      UPDATE masterportal_collections
      SET has_default_icon_pins = TRUE
      WHERE EXISTS (
        SELECT 1 FROM masterportal_pins
        WHERE masterportal_pins.masterportal_collection_id = masterportal_collections.id
          AND masterportal_pins.geometry ->> 'type' = 'Point'
          AND NULLIF(masterportal_pins.properties ->> 'IMAGE_URL', '') IS NULL
      )
    SQL
  end

  def down
    execute("UPDATE masterportal_collections SET contains_shapes = FALSE, has_default_icon_pins = FALSE")
  end
end
