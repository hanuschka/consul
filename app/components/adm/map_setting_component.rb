class Adm::MapSettingComponent < ApplicationComponent
  def initialize(map_location:, path:)
    @map_location = map_location
    @path = path
  end

  attr_reader :map_location, :path

  private

    def geojson_import?
      mappable = map_location.mappable

      mappable.is_a?(ProjektPhase) && mappable.marked_areas_restrictable?
    end

    def geojson_import_data
      return {} unless geojson_import?

      {
        controller: "adm--geojson-area-import",
        action: "map:ready->adm--geojson-area-import#configureMap",
        "adm--geojson-area-import-arm-polygon-tool-value": false,
        "adm--geojson-area-import-max-file-size-value": MapLayer::GEOJSON_MAX_SIZE,
        "adm--geojson-area-import-messages-value": geojson_import_messages
      }
    end

    def geojson_import_messages
      t(".geojson_import.messages").merge(
        too_large: t(".geojson_import.messages.too_large", size: MapLayer::GEOJSON_MAX_SIZE / 1.megabyte)
      )
    end

    def geojson_file_input_id
      dom_id(map_location, :geojson_file)
    end
end
