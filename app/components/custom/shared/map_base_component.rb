class Shared::MapBaseComponent < ApplicationComponent
  delegate :map_location_latitude, :map_location_longitude, :map_location_zoom,
           :map_location_input_id, :projekt_feature?, :projekt_phase_feature?, to: :helpers

  def initialize(
    mappable: nil,
    map_location: nil,
    parent_class:,
    editable: false,
    process_coordinates: nil,
    projekt: nil,
    projekt_phase: nil,
    show_admin_shape: false
  )
    @mappable = mappable
    @map_location = map_location || MapLocation.new
    @parent_class = parent_class
    @editable = editable
    @process_coordinates = process_coordinates || get_process_coordinates
    @projekt = projekt
    @projekt_phase = projekt_phase
    @show_admin_shape = show_admin_shape
  end

  private

    def common_map_settings
      {
        map_center_latitude: map_location_latitude(@map_location),
        map_center_longitude: map_location_longitude(@map_location),
        map_zoom: map_location_zoom(@map_location),

        admin_editor: admin_editor?,

        show_admin_shape: @show_admin_shape,
        admin_shape: admin_shape,

        parent_class: @parent_class,
        process_coordinates: @process_coordinates,

        latitude_input_selector: "##{map_location_input_id(@parent_class, "latitude")}",
        longitude_input_selector: "##{map_location_input_id(@parent_class, "longitude")}",
        zoom_input_selector: "##{map_location_input_id(@parent_class, "zoom")}",
        shape_input_selector: "##{map_location_input_id(@parent_class, "shape")}",
        editable: @editable
      }
    end

    def get_process_coordinates
      if @mappable.present? && @mappable.persisted? && @mappable.map_location.present?
        [
          @mappable.map_location.shape_json_data.presence ||
            @mappable.map_location.json_data
        ]
      else
        []
      end
    end

    def admin_shape
      if @projekt_phase.present?
        @projekt_phase.map_location&.shape_json_data.presence || @projekt_phase.map_location&.json_data&.to_json
      elsif @projekt.present?
        @projekt.map_location.shape_json_data.presence || @projekt.map_location.json_data.to_json
      end
    end

    def admin_editor?
      @parent_class == "projekts" || @parent_class == "projekt_phases"
    end
end
