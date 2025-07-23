module ProjektControllerHelper
  def all_projekts_map_locations(projekt_ids)
    MapLocation.where(projekt_id: projekt_ids).map do |map_location|
      map_location.json_data
    end
  end
end
