class Shared::MapComponent < ApplicationComponent
  def initialize(
    mappable: nil, # map center, zoom, altitu
    features: nil, # map features, e.g. markers, polygons (comes from collection)
    editable: false # if true user can edit the features
  )
    @mappable = mappable
    @features = features || @mappable&.map_location&.features
    @editable = editable
  end

  def map_div
    content_tag :div, "",
                id: dom_id(@mappable, "map"),
                class: "map_location map #{rendering_library}",
                aria: { hidden: true },
                data: prepare_map_settings
  end

  private

    def prepare_map_settings
      options = { map: true }

      options[:map_center_latitude] = map_location&.latitude || Setting["map.latitude"]
      options[:map_center_longitude] = map_location&.longitude || Setting["map.longitude"]
      options[:map_zoom] = map_location&.zoom || Setting["map.zoom"]

      options[:layers_data] = layers

      options[:features] = @features

      options[:admin_features] = admin_features

      options[:editable] = @editable
      options[:enable_shapes] = enable_shapes
      options[:admin_editor] = admin_editor?


      if rendering_library == "mapbox"
        options[:mapbox_public_token] = Rails.application.secrets.dig(:mapbox, :public_token)
        options[:mapbox_style_id] = Rails.application.secrets.dig(:mapbox, :style_id)
        # options[:mapbox_marker_images] = mapbox_marker_images
      elsif rendering_library == "virtualcity"
        options[:map_center_altitude] = map_location&.altitude 
      end

      options
    end

    def map_location
      @map_location ||= @mappable.map_location || MapLocation.new(mappable: @mappable)
    end

    def rendering_library
      @rendering_library ||= map_location&.rendering_library || "leaflet"
    end

    def admin_features
      return {} if admin_editor?
      return {} unless @mappable

      @mappable.try(:projekt_phase)&.map_location&.features ||
        @mappable.try(:projekt)&.map_location&.features
    end

    def layers
      @mappable.try(:projekt_phase)&.map_layers ||
        @mappable.try(:projekt)&.map_layers ||
        MapLayer.general
    end

    def admin_editor?
      @mappable.is_a?(Projekt) || @mappable.is_a?(ProjektPhase)
    end

    def enable_shapes
      return false unless @editable
      return true if admin_editor?

      if @mappable.respond_to?(:projekt_phase) && @mappable.projekt_phase.present?
        projekt_phase_feature?(@mappable.projekt_phase, "form.enable_geoman_controls_in_maps")

      elsif @mappable.is_a?(DeficiencyReport)
        Setting["deficiency_reports.enable_geoman_controls_in_maps"].present?

      elsif @mappable.is_a?(Idea)
        Setting["ideas.enable_geoman_controls_in_maps"].present?

      else
        false
      end
    end
end
