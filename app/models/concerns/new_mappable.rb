module NewMappable
  extend ActiveSupport::Concern

  included do
  has_one :map_location, as: :mappable, dependent: :destroy
    accepts_nested_attributes_for :map_location,
      allow_destroy: true,
      reject_if: proc { |attributes| attributes["latitude"].blank? && attributes["longitude"].blank? }
  end

  def map_layers_for_render
    unless map_layers.any?(&:base?)
      return map_layers.or(MapLayer.where(projekt_id: nil, mappable_id: nil, base: true))
    end

    map_layers
  end

  def map_location_with_default
    map_location ||
      build_map_location(
        latitude: try(:projekt_phase)&.map_location&.latitude,
        longitude: try(:projekt_phase)&.map_location&.longitude,
        zoom: try(:projekt_phase)&.map_location&.zoom
      )
  end
end
