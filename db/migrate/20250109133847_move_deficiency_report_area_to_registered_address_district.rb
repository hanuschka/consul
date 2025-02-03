class MoveDeficiencyReportAreaToRegisteredAddressDistrict < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      INSERT INTO registered_address_districts (name, created_at, updated_at)
      SELECT name, NOW(), NOW()
      FROM deficiency_report_areas
      WHERE name IS NOT NULL
        AND name != ''
        AND NOT EXISTS (
          SELECT 1
          FROM registered_address_districts
          WHERE registered_address_districts.name = deficiency_report_areas.name
        );
    SQL

    execute <<-SQL
      INSERT INTO map_locations (registered_address_district_id, latitude, longitude, zoom, pin_color, shape)
      SELECT
        districts.id, latitude, longitude, zoom, pin_color, shape
      FROM registered_address_districts districts
      JOIN deficiency_report_areas areas
        ON districts.name = areas.name
      JOIN map_locations
        ON map_locations.deficiency_report_area_id = areas.id
      WHERE NOT EXISTS (
        SELECT 1
        FROM map_locations existing_map_locations
        WHERE existing_map_locations.registered_address_district_id = districts.id
      );
    SQL
  end

  def down
  end
end
