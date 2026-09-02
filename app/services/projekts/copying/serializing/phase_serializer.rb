class Projekts::Copying::Serializing::PhaseSerializer < ApplicationService
  # Everything derived from the source's participants (cached stats) or from a
  # completed import run against an external system.
  EXCLUDED_COLUMNS = Projekts::Copying::PhaseCopier::EXCLUDED_COLUMNS

  def initialize(source_phase:)
    @source_phase = source_phase
  end

  def call
    node = Projekts::Copying::Serializing::RecordSerializer.call(
      source_phase, except: EXCLUDED_COLUMNS
    )

    node.merge(
      "settings" => setting_nodes,
      "user_resource_criteria" => serialize_all(source_phase.user_resource_criteria),
      "email_templates" => serialize_all(source_phase.email_templates),
      "local_references" => local_references,
      "map" => Projekts::Copying::Serializing::MapSerializer.call(source: source_phase),
      "resources" => Projekts::Copying::Serializing::PhaseResourceSerializer.call(
        source_phase: source_phase
      )
    )
  end

  private

    attr_reader :source_phase

    def setting_nodes
      source_phase.settings.map do |setting|
        { "key" => setting.key, "value" => setting.value }
      end
    end

    # Rows of THIS instance. A copy made here re-attaches them; an export drops
    # the whole key, because a phase re-attached to a same-named row on another
    # instance would admit or exclude the wrong people without saying so.
    def local_references
      {
        "geozone_restriction_ids" => source_phase.geozone_restrictions.map(&:id),
        "registered_address_district_ids" =>
          source_phase.registered_address_districts.map(&:id),
        "registered_address_street_ids" => source_phase.registered_address_streets.map(&:id),
        "individual_group_value_ids" => source_phase.individual_group_values.map(&:id)
      }
    end

    def serialize_all(records)
      records.map { |record| Projekts::Copying::Serializing::RecordSerializer.call(record) }
    end
end
