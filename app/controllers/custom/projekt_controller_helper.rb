module ProjektControllerHelper
  def all_projekts_map_locations(projekt_ids)
    MapLocation.where(
      mappable_type: "Projekt",
      mappable_id: projekt_ids,
      show_admin_shape: true
    ).map do |map_location|
      map_location.features_json_data
    end
  end
end
