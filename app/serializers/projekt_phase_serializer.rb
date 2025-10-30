class ProjektPhaseSerializer < BaseSerializer
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def serialize
    phase_data = projekt_phase.as_json(
      only: [
        :id,
        :type,
        :start_date,
        :end_date,
        :active,
        :frontend_visibility,
        :given_order,
        :geozone_restricted,
        :age_range_id,
        :user_status,
        :lock_on,
        :registered_address_grouping_restriction,
        :registered_address_grouping_restrictions,
        :comments_count,
        :projekt_id,
        :created_at,
        :updated_at
      ]
    )

    # Add translated attributes if they exist
    translatable_attributes = {}
    if projekt_phase.respond_to?(:phase_tab_name)
      translatable_attributes[:phase_tab_name] = projekt_phase.phase_tab_name
    end
    if projekt_phase.respond_to?(:description)
      translatable_attributes[:description] = projekt_phase.description
    end
    if projekt_phase.respond_to?(:cta_button_name)
      translatable_attributes[:cta_button_name] = projekt_phase.cta_button_name
    end
    if projekt_phase.respond_to?(:welcome_text_in_show)
      translatable_attributes[:welcome_text_in_show] = projekt_phase.welcome_text_in_show
    end

    phase_data.merge!(translatable_attributes) if translatable_attributes.any?

    # Add settings
    phase_data.merge!(
      settings: projekt_phase_settings,
      individual_group_values: individual_group_values,
      geozone_restrictions: geozone_restrictions
    )

    phase_data
  end

  def projekt_phase_settings
    projekt_phase.settings.as_json(only: [:id, :key, :value])
  end

  def individual_group_values
    projekt_phase.individual_group_values.as_json(only: [:id, :name])
  end

  def geozone_restrictions
    projekt_phase.geozone_restrictions.as_json(only: [:id, :name])
  end

  def self.serialize_collection(projekt_phases)
    projekt_phases.map { |phase| new(phase).serialize }
  end
end

