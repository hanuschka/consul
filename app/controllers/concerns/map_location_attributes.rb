module MapLocationAttributes
  extend ActiveSupport::Concern

  def map_location_attributes
    [:latitude, :longitude, :zoom, :shape, :show_admin_shape, :pin_color]
  end
end
