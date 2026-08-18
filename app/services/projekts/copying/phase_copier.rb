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

  def initialize(source_phase:, copy_projekt:, record_copier:)
    @source_phase = source_phase
    @copy_projekt = copy_projekt
    @record_copier = record_copier
  end

  def call
    copy = record_copier.copy_record(
      source_phase,
      attributes: { projekt: copy_projekt },
      except: EXCLUDED_COLUMNS
    )

    copy_settings(copy)
    copy_restrictions(copy)
    copy_resource_criteria(copy)
    copy_email_templates(copy)

    Projekts::Copying::MapCopier.call(
      source: source_phase, copy: copy,
      record_copier: record_copier
    )
    Projekts::Copying::PhaseResourceCopier.call(
      source_phase: source_phase, copy_phase: copy,
      record_copier: record_copier
    )

    copy
  end

  private

    attr_reader :source_phase, :copy_projekt, :record_copier

    # ProjektPhase#add_default_settings seeded the copy with the defaults for
    # its type, so the source's values are applied on top of those rows.
    def copy_settings(copy)
      existing_settings = copy.settings.index_by(&:key)

      source_phase.settings.each do |setting|
        existing = existing_settings[setting.key]

        if existing.present?
          existing.update!(value: setting.value)
        else
          copy.settings.create!(key: setting.key, value: setting.value)
        end
      end
    end

    def copy_restrictions(copy)
      copy.geozone_restrictions = source_phase.geozone_restrictions
      copy.registered_address_districts = source_phase.registered_address_districts
      copy.registered_address_streets = source_phase.registered_address_streets
      copy.individual_group_values = source_phase.individual_group_values
    end

    def copy_resource_criteria(copy)
      record_copier.copy_all(
        source_phase.user_resource_criteria,
        attributes: { projekt_phase: copy }
      )
    end

    def copy_email_templates(copy)
      record_copier.copy_all(
        source_phase.email_templates,
        attributes: { projekt_phase: copy }
      )
    end
end
