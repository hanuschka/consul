class Shared::VCMapComponent < Shared::MapBaseComponent
  def map_div
    content_tag :div,
                id: "myMapUUIDnew",
                data: prepare_map_settings do
      content_tag :span, "Map"
    end
  end

  def show_controls?
    @parent_class != "proposals_sidebar"
  end

  private

    def prepare_map_settings
      options = common_map_settings
      options[:vcmap] = ""
      options[:altitude_input_selector] = "##{map_location_input_id(@parent_class, "altitude")}"
      options[:default_color] = "#00ff00"

      options
    end
end
