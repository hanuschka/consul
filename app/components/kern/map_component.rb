class Kern::MapComponent < ApplicationComponent
  def initialize(
    map_location:,
    form: nil,
    editable: false,
    admin_editor: false,
    gesture_handling: true,
    height: 400,
    width: nil,
    latitude: nil,
    longitude: nil,
    zoom: nil,
    resources: nil,
    feature_collection: nil,
    rendering_library: nil,
    error: nil
  )
    @map_location = map_location
    @rendering_library_override = rendering_library
    @form = form
    @editable = editable
    @admin_editor = admin_editor
    @gesture_handling = gesture_handling
    @height = height
    @width = width
    @latitude = latitude
    @longitude = longitude
    @zoom = zoom
    @resources = resources
    @feature_collection = feature_collection
    @error = error
  end

  attr_reader :map_location, :form, :editable, :admin_editor, :height, :width, :error

  def rendering_library
    @rendering_library_override || map_location.rendering_library || "leaflet"
  end

  def rendering_library_options
    MapLocation.rendering_libraries.keys.map do |key|
      [key, I18n.t("activerecord.attributes.map_location.rendering_libraries.#{key}")]
    end
  end

  def container_id
    base = map_location.default? ? "default_map" : dom_id(mappable, "map")
    @feature_collection.present? ? "#{base}_collection_#{object_id}" : base
  end

  def mappable
    map_location.mappable
  end

  def container_style
    parts = ["height: #{height}px"]
    parts << "width: #{width}px" if width.present?
    parts << "max-width: 100%"
    parts.join("; ") + ";"
  end

  def controller_data_attributes
    {
      controller: "map",
      map_rendering_library_value: rendering_library,
      map_latitude_value: @latitude || map_location.latitude,
      map_longitude_value: @longitude || map_location.longitude,
      map_zoom_value: @zoom || map_location.zoom,
      map_altitude_value: map_location.altitude,
      map_editable_value: editable,
      map_gesture_handling_value: @gesture_handling,
      map_admin_editor_value: admin_editor,
      map_enable_set_center_value: mappable.is_a?(Projekt),
      map_features_value: features_json,
      map_admin_features_value: admin_features_json,
      map_layers_value: layers_json,
      map_mapbox_public_token_value: mapbox_public_token,
      map_mapbox_style_id_value: mapbox_style_id,
      map_masterportal_default_icon_url_value: masterportal_default_icon_url,
      map_vc_map_module_url_value: vc_map_module_url
    }
  end

  private

    def features_json
      if @feature_collection.present?
        @feature_collection.is_a?(String) ? @feature_collection : @feature_collection.to_json
      elsif @resources.present?
        items = MapLocation.where(mappable: @resources).flat_map do |ml|
          parsed = ml.features.is_a?(String) ? JSON.parse(ml.features) : ml.features
          parsed&.dig("features") || []
        end

        { type: "FeatureCollection", features: items }.to_json
      elsif map_location.features.present?
        map_location.features.is_a?(String) ? map_location.features : map_location.features.to_json
      else
        "{}"
      end
    end

    def admin_features_json
      return "{}" if admin_editor

      features = if @resources.present?
                   map_location.features
                 else
                   parent_admin_features
                 end

      return "{}" if features.blank?

      features.is_a?(String) ? features : features.to_json
    end

    def parent_admin_features
      phase = mappable.try(:projekt_phase)
      phase&.map_location&.features
    end

    def layers_json
      layers = if mappable.respond_to?(:map_layers)
                 mappable.map_layers
               else
                 mappable.try(:projekt_phase)&.map_layers ||
                   mappable.try(:projekt)&.map_layers ||
                   MapLayer.default
               end

      serialized = layers.filter_map { |layer| serialize_layer(layer) }

      (masterportal_wms_layer_injection + serialized).to_json
    end

    def serialize_layer(layer)
      common = {
        "id" => layer.id,
        "name" => layer.name,
        "protocol" => layer.protocol,
        "base" => layer.base,
        "show_by_default" => layer.show_by_default,
        "attribution" => layer.attribution
      }

      if layer.geojson?
        # Skip geojson layers without an attached file so data_url is never null.
        return nil unless layer.geojson_file.attached?

        common.merge(
          "data_url" => helpers.url_for(layer.geojson_file),
          "config" => layer.config
        )
      else
        common.merge(
          "provider" => layer.provider,
          "layer_names" => layer.layer_names,
          "transparent" => layer.transparent,
          "opacity" => layer.opacity
        )
      end
    end

    def masterportal_wms_layer_injection
      return [] if map_location.rendering_library != "leaflet_plus_masterportal"

      [{
        "name" => I18n.t("components.kern.map_component.masterportal_wms_layer_name",
                         default: "Masterportal (Regensburg)"),
        "provider" => Rails.application.secrets.dig(:masterportal, :wms_url),
        "layer_names" => Rails.application.secrets.dig(:masterportal, :wms_layers).to_s,
        "protocol" => "wms",
        "transparent" => true,
        "opacity" => 0.8,
        "show_by_default" => true,
        "base" => false
      }]
    end

    def masterportal_default_icon_url
      helpers.image_path("masterportal/pins/default_pin.svg")
    end

    def mapbox_public_token
      ExternalApiKey.mapbox_public_token
    end

    def mapbox_style_id
      map_location.mapbox_style_id.presence || Rails.application.secrets.dig(:mapbox, :style_id)
    end

    def vc_map_module_url
      Rails.application.secrets.vc_map_module
    end
end
