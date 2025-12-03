class Shared::MapComponent < ApplicationComponent
  def initialize(
    mappable: nil, # map center, zoom, altitu
    features: {}, # map features, e.g. markers, polygons (comes from collection)
    editable: false, # if true user can edit the features
    process: nil,
    placement: nil # used to determine the placement of the map (e.g. in a modal or on a page
  )
    @mappable = mappable
    @features = features
    @editable = editable
    @process = process
    @placement = placement
  end

  def map_div
    content_tag :div, "",
                id: map_id,
                class: "map_location map #{rendering_library}",
                aria: { hidden: true },
                data: prepare_map_settings
  end

  private

    def prepare_map_settings
      options = { map: true }

      options[:process] = @process if @process
      options[:map_location_id] = @mappable.map_location.id if @mappable&.map_location

      options[:map_center_latitude] = map_location&.latitude || Setting["map.latitude"]
      options[:map_center_longitude] = map_location&.longitude || Setting["map.longitude"]
      options[:map_zoom] = map_location&.zoom || Setting["map.zoom"]
      options[:placement] = @placement if @placement

      options[:layers_data] = layers

      options[:features] = @features

      options[:admin_features] = admin_features

      options[:editable] = @editable
      options[:enable_shapes] = enable_shapes
      options[:admin_editor] = admin_editor?
      options[:editing_projekt_map] = editing_projekt_map?
      options[:map_features_limit] = map_features_limit if @editable

      if rendering_library == "mapbox"
        options[:mapbox_public_token] = Rails.application.secrets.dig(:mapbox, :public_token)
        options[:mapbox_style_id] = Rails.application.secrets.dig(:mapbox, :style_id)
      elsif rendering_library == "virtualcity"
        options[:map_center_altitude] = map_location&.altitude 
      end

      options
    end

    def map_id
      return dom_id(@mappable, [@placement, "map"].compact.join("_")) if @mappable
      return "#{@process}_map" if @process
      return "default_map" if map_location.default?

      "map"
    end

    def map_location
      @map_location ||= if @mappable.present?
                          @mappable.map_location || MapLocation.new(mappable: @mappable)
                        else
                          MapLocation.default
                        end
    end

    def rendering_library
      @rendering_library ||= map_location&.rendering_library || "leaflet"
    end

    def admin_features
      if admin_editor?
        return { type: "FeatureCollection", features: [] }.to_json
      elsif @mappable.is_a?(ProjektPhase) || @mappable.is_a?(Projekt) || map_location.default?
        return map_location.features.to_json
      end

      @mappable.try(:projekt_phase)&.map_location&.features&.to_json ||
        @mappable.try(:projekt)&.map_location&.features&.to_json
    end

    def layers
      return @mappable.map_layers if @mappable.is_a?(ProjektPhase) || @mappable.is_a?(Projekt)

      @mappable.try(:projekt_phase)&.map_layers ||
        @mappable.try(:projekt)&.map_layers ||
        MapLayer.general
    end

    def admin_editor?
      return false unless @editable

      admin_mappables = [Projekt, ProjektPhase, RegisteredAddress::District]
      admin_mappables.any? { |klass| @mappable.is_a?(klass) } || map_location.default?
    end

    def editing_projekt_map?
      admin_editor? && @mappable.is_a?(Projekt)
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

    def map_features_limit
      if @mappable.respond_to?(:projekt_phase)
        @mappable.projekt_phase.option("form.map_features_limit")
      else
        1
      end
    end
end
