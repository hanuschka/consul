# The whole location of a resource: the point, the shapes and lines drawn on
# the map (GeoJSON in `features`) and how they are displayed. The id lets a
# client update the location in place.
class MapLocationSerializer
  def initialize(map_location)
    @map_location = map_location
  end

  def serialize
    {
      id: map_location.id,
      latitude: map_location.latitude,
      longitude: map_location.longitude,
      altitude: map_location.altitude,
      zoom: map_location.zoom,
      approximated_address: map_location.approximated_address,
      features: MapLocation.normalize_feature_collection(map_location.features),
      pin_color: map_location.pin_color,
      show_admin_shape: map_location.show_admin_shape,
      rendering_library: map_location.rendering_library,
      mapbox_style_id: map_location.mapbox_style_id
    }
  end

  private

    attr_reader :map_location
end
