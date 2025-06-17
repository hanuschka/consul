class Shared::MapComponent < Shared::MapBaseComponent
  def map_div
    content_tag :div, "",
                id: "#{dom_id(@map_location)}_#{@parent_class}",
                class: "map_location map",
                data: prepare_map_settings
  end

  private

    def prepare_map_settings
      options = common_map_settings
      options[:map] = ""
      options[:enable_geoman_controls] = enable_geoman_controls?
      options[:map_layers] = map_layers if map_layers.present?

      options
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
