module ProjektControllerHelper
  def all_projekts_map_locations(projekt_ids)
    MapLocation.where(
      mappable_type: "Projekt",
      mappable_id: projekt_ids,
      show_admin_shape: true
    ).map(&:json_data)
  end
end
