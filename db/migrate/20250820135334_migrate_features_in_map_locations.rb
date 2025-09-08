class MigrateFeaturesInMapLocations < ActiveRecord::Migration[6.1]
  def up
    unless column_exists?(:map_locations, :features_bu)
      add_column :map_locations, :features_bu, :jsonb, default: {}, null: false

      execute <<-SQL.squish
        UPDATE map_locations
        SET features_bu = features
      SQL
    end

    MapLocation.find_each(batch_size: 1000) do |loc|
      next unless loc.latitude && loc.longitude

      if loc.features.nil? || loc.features == {} || loc.features == "{}"
        geojson_point = {
          type: "FeatureCollection",
          features: [
            {
              type: "Feature",
              properties: {},
              geometry: {
                type: "Point",
                coordinates: [loc.longitude, loc.latitude]
              }
            }
          ]
        }

        loc.update_column(:features, geojson_point)
      elsif loc.features.is_a?(String)
        begin
          parsed = JSON.parse(loc.features)
          loc.update_column(:features, parsed)
        rescue JSON::ParserError => e
          Rails.logger.error "Failed to parse JSON for MapLocation ID #{loc.id}: #{e.message}"
        end
      end
    end
  end

  def down
  end
end
