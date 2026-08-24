class Projekts::Copying::PhaseCopier < ApplicationService
  # Everything derived from the source's participants (cached stats) or from a
  # completed import run against an external system.
  EXCLUDED_COLUMNS = %w[
    projekt_id
    ai_stats ai_stats_refresh_status ai_stats_refreshed_at
    stats stats_refreshed_at
    masterportal_import_status masterportal_last_imported_at
    masterportal_last_imported_count masterportal_import_error
    masterportal_last_endpoint_url masterportal_last_collection_ids
    masterportal_destroy_status masterportal_destroy_error
    mitmachbox_survey_id
  ].freeze

  def initialize(node:, copy_projekt:, record_copier:)
    @node = node
    @copy_projekt = copy_projekt
    @record_copier = record_copier
  end

  def call
    copy = record_copier.copy_record(
      node,
      attributes: { projekt: copy_projekt },
      except: EXCLUDED_COLUMNS
    )

    copy_settings(copy)
    copy_restrictions(copy)
    copy_resource_criteria(copy)
    copy_email_templates(copy)

    Projekts::Copying::MapCopier.call(
      node: node["map"], copy: copy,
      record_copier: record_copier
    )
    Projekts::Copying::PhaseResourceCopier.call(
      node: node["resources"], copy_phase: copy,
      record_copier: record_copier
    )

    copy
  end

  private

    attr_reader :node, :copy_projekt, :record_copier

    def local_references
      node["local_references"] || {}
    end

    # ProjektPhase#add_default_settings seeded the copy with the defaults for
    # its type, so the source's values are applied on top of those rows.
    def copy_settings(copy)
      existing_settings = copy.settings.index_by(&:key)

      Array(node["settings"]).each do |setting|
        existing = existing_settings[setting["key"]]

        if existing.present?
          existing.update!(value: setting["value"])
        else
          copy.settings.create!(key: setting["key"], value: setting["value"])
        end
      end
    end

    # Empty on an imported bundle: every restriction names a row of this
    # instance, and a phase re-attached to a same-named row elsewhere would
    # admit or exclude the wrong people without saying so.
    def copy_restrictions(copy)
      copy.geozone_restrictions =
        Geozone.where(id: local_references["geozone_restriction_ids"])
      copy.registered_address_districts =
        RegisteredAddress::District.where(id: local_references["registered_address_district_ids"])
      copy.registered_address_streets =
        RegisteredAddress::Street.where(id: local_references["registered_address_street_ids"])
      copy.individual_group_values =
        IndividualGroupValue.where(id: local_references["individual_group_value_ids"])
    end

    def copy_resource_criteria(copy)
      record_copier.copy_all(
        node["user_resource_criteria"],
        attributes: { projekt_phase: copy }
      )
    end

    def copy_email_templates(copy)
      record_copier.copy_all(
        node["email_templates"],
        attributes: { projekt_phase: copy }
      )
    end
end
