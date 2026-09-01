class AddIconUrlToMasterportalCollections < ActiveRecord::Migration[6.1]
  def up
    add_column :masterportal_collections, :icon_url, :string

    execute(<<~SQL.squish)
      UPDATE masterportal_collections mc
      SET icon_url = sub.image_url
      FROM (
        SELECT DISTINCT ON (masterportal_collection_id)
               masterportal_collection_id,
               NULLIF(TRIM(properties->>'IMAGE_URL'), '') AS image_url
        FROM masterportal_pins
        WHERE masterportal_collection_id IS NOT NULL
        ORDER BY masterportal_collection_id, id DESC
      ) sub
      WHERE mc.id = sub.masterportal_collection_id
        AND sub.image_url IS NOT NULL
    SQL
  end

  def down
    remove_column :masterportal_collections, :icon_url
  end
end
