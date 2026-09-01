class Projekts::Copying::MapCopier < ApplicationService
  def initialize(node:, copy:, record_copier:)
    @node = node
    @copy = copy
    @record_copier = record_copier
  end

  # Projekt#copy_map_settings already gave the copy a blank map location and a
  # set of default layers on create, so both are replaced rather than added to.
  def call
    return if node.blank?

    copy_map_location
    copy_map_layers
  end

  private

    attr_reader :node, :copy, :record_copier

    def copy_map_location
      location_node = node["location"]
      return if location_node.blank?

      location_copy = record_copier.overwrite_or_copy(
        location_node, copy.map_location,
        attributes: { mappable: copy }
      )

      record_copier.copy_attachment(location_node, :screenshot, location_copy.screenshot)
    end

    # Geojson layers are already absent: their uploaded file is their only
    # geometry and MapLayer validates it for presence, so the serializer leaves
    # them out rather than let an invalid layer abort the whole copy.
    def copy_map_layers
      copy.map_layers.destroy_all

      Array(node["layers"]).each do |layer_node|
        record_copier.copy_record(
          layer_node,
          attributes: { mappable: copy, projekt_id: legacy_projekt_id(layer_node) }
        )
      end
    end

    # map_layers still carries a pre-polymorphic projekt_id alongside the
    # mappable association; it has to follow the copy, not the source, and only
    # layers that had one get one.
    def legacy_projekt_id(layer_node)
      return nil if layer_node.dig("references", "projekt_id").blank?
      return copy.id if copy.is_a?(Projekt)

      copy.projekt_id
    end
end
