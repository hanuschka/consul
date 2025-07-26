class Shared::MapBaseComponent < ApplicationComponent
  delegate :map_location_latitude, :map_location_longitude, :map_location_zoom,
           :map_location_input_id, :projekt_feature?, :projekt_phase_feature?, to: :helpers

  def initialize(
    mappable: nil,
    map_location: nil,
    parent_class: nil,
    editable: false,
    process_coordinates: nil,
    projekt: nil,
    projekt_phase: nil,
    admin_editor: false,
    show_admin_shape: true,
    saturated_admin_shape: false,
    dont_open_marker_popup: false,
    set_admin_center_with_marker: false
  )
    @mappable = mappable
    @map_location = map_location || MapLocation.new
    @parent_class = parent_class
    @editable = editable
    @set_admin_center_with_marker = set_admin_center_with_marker
    @admin_editor = admin_editor
    @projekt = projekt
    @projekt_phase = projekt_phase
    @show_admin_shape = show_admin_shape
    @saturated_admin_shape = saturated_admin_shape
    @dont_open_marker_popup = dont_open_marker_popup
    @process_coordinates = process_coordinates
  end

  private

    def process_coordinates_to_use
      @_process_coordinates_to_use ||=
        (@process_coordinates || get_process_coordinates)
    end

    def common_map_settings
      {
        map_center_latitude: map_location_latitude(@map_location),
        map_center_longitude: map_location_longitude(@map_location),
        map_zoom: map_location_zoom(@map_location),

        admin_editor: @admin_editor,

        show_admin_shape: @show_admin_shape,
        admin_shape: admin_shape,
        saturated_admin_shape: @saturated_admin_shape,

        parent_class: @parent_class,
        process_coordinates: process_coordinates_to_use,

        latitude_input_selector: "##{map_location_input_id(@parent_class, "latitude")}",
        longitude_input_selector: "##{map_location_input_id(@parent_class, "longitude")}",
        zoom_input_selector: "##{map_location_input_id(@parent_class, "zoom")}",
        shape_input_selector: "##{map_location_input_id(@parent_class, "shape")}",
        editable: @editable,
        dont_open_marker_popup: @dont_open_marker_popup,
        set_admin_center_with_marker: @set_admin_center_with_marker,
        colors: colors
      }
    end

    def get_process_coordinates
      if @mappable.present? && @mappable.persisted? && @mappable.map_location.present?
        if @admin_editor
          if @set_admin_center_with_marker
            [
              @mappable.map_location.json_data, @mappable.map_location.shape_json_data
            ]
          else
            [
              @mappable.map_location.shape_json_data
            ]
          end
        else
          [
            @mappable.map_location.shape_json_data.presence ||
              @mappable.map_location.json_data
          ]
        end
      else
        []
      end
    end

    def admin_shape
      if @projekt_phase.present?
        @projekt_phase.map_location&.shape_json_data.presence
      elsif @projekt.present?
        @projekt.map_location.shape_json_data.presence
      end
    end

    def colors
      {
        admin_shapes: "red",
        projekt_center_marker: "#004a83"
      }.to_json
    end
end
