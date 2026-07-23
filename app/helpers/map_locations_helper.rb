module MapLocationsHelper
  def map_location_available?(map_location_or_resource)
    map_location = resolve_map_location(map_location_or_resource)

    map_location.present? && map_location.available?
  end

  def map_location_latitude(map_location)
    map_location.present? && map_location.latitude.present? ? map_location.latitude : Setting["map.latitude"]
  end

  def map_location_longitude(map_location)
    map_location.present? && map_location.longitude.present? ? map_location.longitude : Setting["map.longitude"]
  end

  def map_location_zoom(map_location)
    map_location.present? && map_location.zoom.present? ? map_location.zoom : Setting["map.zoom"]
  end

  def map_location_input_id(prefix, attribute)
    "#{prefix}_map_location_attributes_#{attribute}"
  end

  private

    def resolve_map_location(map_location_or_resource)
      return map_location_or_resource if map_location_or_resource.is_a?(MapLocation)
      return nil if map_location_or_resource.blank?

      if map_location_or_resource.respond_to?(:projekt_phase)
        map_location_or_resource.map_location ||
          map_location_or_resource.projekt_phase&.map_location_with_admin_shape
      elsif map_location_or_resource.respond_to?(:map_location)
        map_location_or_resource.map_location
      end
    end
end
