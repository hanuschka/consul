class Kern::MapComponent < ApplicationComponent
  def initialize(
    map_location:,
    form: nil,
    editable: false,
    admin_editor: false,
    height: 400,
    resources: nil
  )
    @map_location = map_location
    @form = form
    @editable = editable
    @admin_editor = admin_editor
    @height = height
    @resources = resources
  end

  attr_reader :map_location, :form, :editable, :admin_editor, :height

  def rendering_library_options
    MapLocation.rendering_libraries.keys.map do |key|
      [key, I18n.t("activerecord.attributes.map_location.rendering_libraries.#{key}")]
    end
  end

  def container_id
    map_location.default? ? "default_map" : dom_id(mappable, "map")
  end

  def mappable
    map_location.mappable
  end

  def container_style
    "height: #{height}px;"
  end

  def controller_data_attributes
    {
      controller: "map",
      map_rendering_library_value: rendering_library,
      map_latitude_value: map_location.latitude,
      map_longitude_value: map_location.longitude,
      map_zoom_value: map_location.zoom,
      map_altitude_value: map_location.altitude,
      map_editable_value: editable,
      map_admin_editor_value: admin_editor,
      map_enable_set_center_value: mappable.is_a?(Projekt),
      map_features_value: features_json,
      map_admin_features_value: admin_features_json,
      map_layers_value: layers_json,
      map_mapbox_public_token_value: mapbox_public_token,
      map_mapbox_style_id_value: mapbox_style_id,
      map_vc_map_module_url_value: vc_map_module_url
    }
  end

  private

    def rendering_library
      map_location.rendering_library || "leaflet"
    end

    def features_json
      if @resources.present?
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
      layers.to_json
    end

    def mapbox_public_token
      Rails.application.secrets.dig(:mapbox, :public_token)
    end

    def mapbox_style_id
      Rails.application.secrets.dig(:mapbox, :style_id)
    end

    def vc_map_module_url
      Rails.application.secrets.vc_map_module
    end
end
