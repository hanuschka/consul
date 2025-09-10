module Mappable
  extend ActiveSupport::Concern

  included do
    has_one :map_location, as: :mappable, dependent: :destroy

    accepts_nested_attributes_for :map_location,
      allow_destroy: true,
      reject_if: proc { |attrs| attrs["features"] == "{}" && !attrs["mappable_type"].in?(%w[Projekt ProjektPhase]) }
  end

  def map_layers_for_render
    unless map_layers.any?(&:base?)
      return map_layers.or(MapLayer.where(projekt_id: nil, mappable_id: nil, base: true))
    end

    map_layers
  end
end
