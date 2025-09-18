class RenameShapeToFeaturesInMapLocations < ActiveRecord::Migration[6.1]
  def change
    rename_column :map_locations, :shape, :features
  end
end
