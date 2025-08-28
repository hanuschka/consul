module MapLocationAttributes
  extend ActiveSupport::Concern

  def map_location_attributes
    [:id, :latitude, :longitude, :altitude, :zoom, :features, :rendering_library, :_destroy]
  end
end
