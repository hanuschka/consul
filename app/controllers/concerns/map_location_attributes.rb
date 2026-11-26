module MapLocationAttributes
  extend ActiveSupport::Concern

  def map_location_attributes
    [:id, :latitude, :longitude, :altitude, :zoom, :features, :rendering_library, :show_admin_shape, :_destroy]
  end

  # API clients send the GeoJSON in `features` as an object or as a string.
  def map_location_attributes_api
    [
      :id, :latitude, :longitude, :altitude, :zoom, :features, :pin_color,
      :rendering_library, :mapbox_style_id, :show_admin_shape, :_destroy,
      { features: {} }
    ]
  end
end
