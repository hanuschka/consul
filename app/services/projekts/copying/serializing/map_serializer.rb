class Projekts::Copying::Serializing::MapSerializer < ApplicationService
  def initialize(source:)
    @source = source
  end

  def call
    {
      "location" => location_node,
      "layers" => layer_nodes
    }
  end

  private

    attr_reader :source

    def location_node
      map_location = source.map_location
      return nil if map_location.blank?

      Projekts::Copying::Serializing::RecordSerializer.call(
        map_location, attachments: %i[screenshot]
      )
    end

    # A geojson layer's uploaded file is its only geometry and MapLayer
    # validates it for presence, so the layer is dropped rather than carried
    # empty -- an invalid layer would abort the whole copy. projekt_id is a
    # pre-polymorphic leftover, and only layers that had one get one on the copy.
    def layer_nodes
      source.map_layers.reject(&:geojson?).map do |map_layer|
        Projekts::Copying::Serializing::RecordSerializer.call(
          map_layer, references: %w[projekt_id]
        )
      end
    end
end
