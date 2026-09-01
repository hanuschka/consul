class AddSourceToMasterportalCollections < ActiveRecord::Migration[6.1]
  def up
    add_column :masterportal_collections, :source, :string, null: false, default: "geoserver"
  end

  def down
    remove_column :masterportal_collections, :source
  end
end
