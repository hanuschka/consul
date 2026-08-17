class Projekts::Copying::MapCopier < ApplicationService
  EXCLUDED_LOCATION_COLUMNS = %w[mappable_type mappable_id].freeze

  def initialize(source:, copy:, record_copier:)
    @source = source
    @copy = copy
    @record_copier = record_copier
  end

  # Projekt#copy_map_settings already gave the copy a blank map location and a
  # set of default layers on create, so both are replaced rather than added to.
  def call
    copy_map_location
    copy_map_layers
  end

  private

    attr_reader :source, :copy, :record_copier

    def copy_map_location
      source_location = source.map_location
      return if source_location.blank?

      record_copier.overwrite_or_copy(
        source_location, copy.map_location,
        attributes: { mappable: copy },
        except: EXCLUDED_LOCATION_COLUMNS
      )
    end

    def copy_map_layers
      copy.map_layers.destroy_all

      source.map_layers.each do |map_layer|
        record_copier.copy_record(
          map_layer,
          attributes: { mappable: copy, projekt_id: legacy_projekt_id(map_layer) }
        )
      end
    end

    # map_layers still carries a pre-polymorphic projekt_id alongside the
    # mappable association; it has to follow the copy, not the source.
    def legacy_projekt_id(map_layer)
      return nil if map_layer.projekt_id.blank?
      return copy.id if copy.is_a?(Projekt)

      copy.projekt_id
    end
end
