class Shared::MapComponent < Shared::MapBaseComponent
  def map_div
    content_tag :div, "",
                id: "#{dom_id(@map_location)}_#{@parent_class}",
                class: "map_location map #{map_lib_class}",
                data: prepare_map_settings
  end

  private

    def map_lib_class
      if use_mapbox?
        "custom-mapbox-map-styles"
      else
        "custom-leaflet-map-styles"
      end
    end

    def prepare_map_settings
      options = common_map_settings
      options[:enable_geoman_controls] = enable_geoman_controls?
      options[:map_layers] = map_layers if map_layers.present?

      if use_mapbox?
        options.delete(:map)
        options[:mapbox] = true
        options[:mapbox_public_token] = Rails.application.secrets.mapbox[:public_token]
        options[:mapbox_marker_images] = mapbox_marker_images
        options[:mapbox_style_id] = mapbox_style_id

      elsif map_style == "regular"
        options[:map] = ""
      end

      options
    end

    def mapbox_marker_images
      @process_coordinates.map { |coordinate|
        icon = coordinate[:fa_icon_class]

        if icon.present?
          {
            name: icon,
            path: asset_path("fontawesome_png/solid/#{icon}_50px.png")
          }
        end
      }
        .compact
        .uniq { |icon| icon[:name] }
    end

    def use_mapbox?
      if @projekt_phase.present?
        Setting["feature.mapbox"].present? || projekt_phase_feature?(@projekt_phase, "general.mapbox")
      else
        Setting["feature.mapbox"].present?
      end
    end

    def enable_geoman_controls?
      return false unless @editable

      if @mappable.is_a?(DeficiencyReport) || @mappable.is_a?(Projekt)
        Setting["deficiency_reports.enable_geoman_controls_in_maps"].present?

      elsif @projekt_phase.present?
        projekt_phase_feature?(@projekt_phase, "form.enable_geoman_controls_in_maps")

      else
        false
      end
    end

    def mapbox_style_id
      Rails.application.secrets.dig(:mapbox, :style_id)
    end

    def map_layers
      if @projekt_phase.present?
        @projekt_phase.map_layers_for_render.to_json
      elsif @projekt.present?
        @projekt.map_layers_for_render.to_json
      else
        MapLayer.general.to_json
      end
    end
end
