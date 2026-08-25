class Shared::MapComponent < ApplicationComponent
  LAZY_LOAD_THRESHOLD = 200

  def initialize(
    mappable: nil,
    features: {},
    features_count: nil,
    editable: false,
    process: nil,
    placement: nil,
    rendering_library: nil,
    map_data_url: nil,
    lazy_load_threshold: LAZY_LOAD_THRESHOLD,
    masterportal_focus_view: false,
    instance_suffix: nil
  )
    @mappable = mappable
    @features = features
    @explicit_features_count = features_count
    @editable = editable
    @process = process
    @placement = placement
    @rendering_library_override = rendering_library
    @map_data_url = map_data_url
    @lazy_load_threshold = lazy_load_threshold
    @masterportal_focus_view = masterportal_focus_view
    @instance_suffix = instance_suffix
  end

  def lazy_load_map_data?
    return false if @editable
    return false if @map_data_url.blank?

    (@explicit_features_count || features_count) > @lazy_load_threshold
  end

  def hide_from_screen_readers?
    return false if @editable
    return false if extended_sidebar_map?

    true
  end

  def map_accessibility_note
    key =
      if @process.present?
        "custom.map.not_accessible_note_listing"
      else
        "custom.map.not_accessible_note_single"
      end

    I18n.t(key)
  end

  def map_div
    content_tag :div, "",
                id: map_id,
                class: "map_location map #{rendering_library}",
                role: "application",
                aria: { label: I18n.t("custom.accessibility.map.region_label") },
                data: prepare_map_settings
  end

  private

    def extended_sidebar_map?
      @placement == "extended_sidebar_map"
    end

    def features_count
      data = resolved_features

      array =
        if data.is_a?(Hash)
          data[:features] || data["features"]
        else
          data
        end

      array.is_a?(Array) ? array.size : 0
    end

    def resolved_features
      return @features if !@masterportal_focus_view

      @resolved_features ||=
        map_location.features_json_data(mark_masterportal_pin: false)
    end

    def masterportal_focus?
      @masterportal_focus_view && masterportal_rendering_enabled?
    end

    def prepare_map_settings
      options = { map: true }

      options[:process] = @process if @process
      options[:map_location_id] = @mappable.map_location.id if @mappable&.map_location

      options[:map_center_latitude] = map_location&.latitude || Setting["map.latitude"]
      options[:map_center_longitude] = map_location&.longitude || Setting["map.longitude"]
      options[:map_zoom] = map_zoom
      options[:placement] = @placement if @placement

      options[:layers_data] = layers

      if lazy_load_map_data?
        options[:map_data_url] = @map_data_url
      else
        options[:features] = resolved_features
      end

      options[:masterportal_pins_layer_label] =
        I18n.t("components.shared.map_component.layers.masterportal_pins")
      options[:masterportal_default_icon_url] =
        helpers.path_to_image("masterportal/pins/default_pin.svg")

      options[:admin_features] = admin_features

      options[:editable] = @editable
      options[:enable_shapes] = enable_shapes
      options[:admin_editor] = admin_editor?
      options[:editing_projekt_map] = editing_projekt_map?
      options[:map_features_limit] = map_features_limit if @editable

      if rendering_library == "mapbox"
        options[:mapbox_public_token] = ExternalApiKey.mapbox_public_token
        options[:mapbox_style_id] = map_location.mapbox_style_id.presence || Rails.application.secrets.dig(:mapbox, :style_id)
      elsif rendering_library == "virtualcity"
        options[:map_center_altitude] = map_location&.altitude
        options[:vc_map_module_url] = Rails.application.secrets.vc_map_module
      end

      options
    end

    def map_id
      base =
        if @mappable
          dom_id(@mappable, [@placement, "map"].compact.join("_"))
        elsif @process
          "#{@process}_map"
        elsif map_location.default?
          "default_map"
        else
          "map"
        end

      [base, @instance_suffix].compact.join("_")
    end

    def map_zoom
      context_zoom = @masterportal_focus_view ? context_map_location&.zoom : nil

      context_zoom || map_location&.zoom || Setting["map.zoom"]
    end

    def map_location
      @map_location ||= if @mappable.present?
                          @mappable.map_location || MapLocation.new(mappable: @mappable)
                        else
                          MapLocation.default
                        end
    end

    def rendering_library
      lib = @rendering_library_override || map_location&.rendering_library || "leaflet"
      @rendering_library ||= lib == "leaflet_plus_masterportal" ? "leaflet" : lib
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
      base = if @mappable.is_a?(ProjektPhase) || @mappable.is_a?(Projekt)
               @mappable.map_layers
             else
               @mappable.try(:inherited_map_layers) ||
                 @mappable.try(:projekt_phase)&.map_layers ||
                 @mappable.try(:projekt)&.map_layers ||
                 MapLayer.default
             end

      base_layers = base.filter_map do |layer|
        json = layer.as_json

        if layer.geojson?
          # Skip geojson layers without an attached file so data_url is never null.
          next nil unless layer.geojson_file.attached?

          json["data_url"] = helpers.url_for(layer.geojson_file)
        end

        json
      end

      if masterportal_focus?
        base_layers = base_layers.reject do |layer|
          layer["protocol"] == "wms" && !layer["base"]
        end
      end

      masterportal_wms_layer_injection + base_layers
    end

    def masterportal_wms_layer_injection
      return [] if !masterportal_rendering_enabled?

      wms_url = Rails.application.secrets.dig(:masterportal, :wms_url)
      wms_layers = Rails.application.secrets.dig(:masterportal, :wms_layers)

      return [] if wms_url.blank? || wms_layers.blank?

      [{
        "name" => I18n.t("components.shared.map_component.layers.masterportal_wms_layer_name",
                         default: "Masterportal (Regensburg)"),
        "provider" => wms_url,
        "layer_names" => wms_layers.to_s,
        "protocol" => "wms",
        "transparent" => true,
        "opacity" => 0.8,
        "show_by_default" => true,
        "base" => false
      }]
    end

    def masterportal_rendering_enabled?
      return true if map_location&.rendering_library == "leaflet_plus_masterportal"

      context_map_location&.rendering_library == "leaflet_plus_masterportal"
    end

    def context_map_location
      @mappable.try(:projekt_phase)&.map_location ||
        @mappable.try(:projekt)&.map_location
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
