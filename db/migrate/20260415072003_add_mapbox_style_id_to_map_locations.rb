class AddMapboxStyleIdToMapLocations < ActiveRecord::Migration[6.1]
  def change
    add_column :map_locations, :mapbox_style_id, :string
  end
end
