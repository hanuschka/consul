class Projekts::Copying::MapCopier < ApplicationService
  def initialize(source:, copy:, record_copier:)
    @source = source
    @copy = copy
    @record_copier = record_copier
    @blob_copier = record_copier.blob_copier
  end

  # Projekt#copy_map_settings already gave the copy a blank map location and a
  # set of default layers on create, so both are replaced rather than added to.
  def call
    copy_map_location
    copy_map_layers
  end

  private

    attr_reader :source, :copy, :record_copier, :blob_copier

    def copy_map_location
      source_location = source.map_location
      return if source_location.blank?

      location_copy = record_copier.overwrite_or_copy(
        source_location, copy.map_location,
        attributes: { mappable: copy }
      )

      blob_copier.copy_one(source_location.screenshot, location_copy.screenshot)
    end

    def copy_map_layers
      copy.map_layers.destroy_all

      source.map_layers.each do |map_layer|
        if map_layer.geojson?
          log_skipped_geojson_layer(map_layer)
          next
        end

        record_copier.copy_record(
          map_layer,
          attributes: { mappable: copy, projekt_id: legacy_projekt_id(map_layer) }
        )
      end
    end

    # The uploaded file is a geojson layer's only geometry and MapLayer
    # validates it for presence, so the layer is dropped rather than copied
    # empty -- an invalid layer would abort the whole projekt copy.
    def log_skipped_geojson_layer(map_layer)
      Rails.logger.warn(
        "[Projekts::Copying::MapCopier] skipped geojson map layer #{map_layer.id} " \
        "(#{map_layer.name}) of #{source.class.name} #{source.id}"
      )
    end

    # map_layers still carries a pre-polymorphic projekt_id alongside the
    # mappable association; it has to follow the copy, not the source.
    def legacy_projekt_id(map_layer)
      return nil if map_layer.projekt_id.blank?
      return copy.id if copy.is_a?(Projekt)

      copy.projekt_id
    end
end
