module MapLocationAttributes
  extend ActiveSupport::Concern

  def map_location_attributes
    [:id, :latitude, :longitude, :altitude, :zoom, :shape, :show_admin_shape, :pin_color, :_destroy]
  end
end
