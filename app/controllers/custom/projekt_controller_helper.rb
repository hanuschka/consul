module ProjektControllerHelper
  def all_projekts_map_locations(projekt_ids)
    # json_data probes `mappable` for sentiment/category/projekt_labels, so
    # without this include every location loads its Projekt on its own.
    MapLocation.where(
      mappable_type: "Projekt",
      mappable_id: projekt_ids,
      show_admin_shape: true
    ).includes(:mappable).map(&:json_data)
  end
end
