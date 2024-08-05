class AddGeocoderDataToMapLocations < ActiveRecord::Migration[6.1]
  def change
    add_column :map_locations, :geocoder_data, :jsonb, default: {}
  end
end
