# frozen_string_literal: true

class MunicipalPlans::OverviewMapComponent < ApplicationComponent
  NOTE_ID = "municipal-plans-map-note"

  attr_reader :overview_map

  def initialize(overview_map:)
    @overview_map = overview_map
  end

  def render?
    overview_map.show?
  end

  def rendering_library
    @rendering_library ||= map_location.rendering_library == "mapbox" ? "mapbox" : "leaflet"
  end

  def map_data
    data = {
      library: rendering_library,
      bounds: overview_map.bounds,
      latitude: map_location.latitude || Setting["map.latitude"],
      longitude: map_location.longitude || Setting["map.longitude"],
      zoom: map_location.zoom || Setting["map.zoom"],
      areas: overview_map.areas,
      markers: overview_map.markers
    }

    if rendering_library == "mapbox"
      data[:mapbox_token] = ExternalApiKey.mapbox_public_token
      data[:mapbox_style] = map_location.mapbox_style_id.presence ||
                            Rails.application.secrets.dig(:mapbox, :style_id)
    else
      data[:tile_layer] = tile_layer
    end

    data
  end

  private

    def map_location
      @map_location ||= MapLocation.default
    end

    def tile_layer
      layer = MapLayer.default.where(base: true).first
      return if layer.nil?

      {
        protocol: layer.protocol,
        provider: layer.provider,
        attribution: layer.attribution,
        layer_names: layer.layer_names,
        transparent: layer.transparent,
        opacity: layer.opacity&.to_f
      }
    end
end
