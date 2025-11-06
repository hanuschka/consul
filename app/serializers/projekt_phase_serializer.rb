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

    phase_data[:active] = false if phase_data[:active].nil?

    # Add translated attributes if they exist
    translatable_attributes = {}
    if projekt_phase.respond_to?(:phase_tab_name)
      translatable_attributes[:phase_tab_name] = projekt_phase.phase_tab_name || projekt_phase.type.split('::').last
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

    # Add resources based on phase type
    resources_data = phase_resources
    phase_data.merge!(resources_data) if resources_data.any?

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

  def phase_resources
    case projekt_phase
    when ProjektPhase::ProposalPhase
      { proposals: serialize_proposals }
    when ProjektPhase::BudgetPhase
      { budget: serialize_budget }
    when ProjektPhase::VotingPhase
      { polls: serialize_polls }
    when ProjektPhase::LivestreamPhase
      { projekt_livestreams: serialize_livestreams, questions: serialize_questions }
    when ProjektPhase::QuestionPhase
      { questions: serialize_questions }
    when ProjektPhase::FormularPhase
      { formular: serialize_formular }
    when ProjektPhase::EventPhase
      { projekt_events: serialize_events }
    when ProjektPhase::ArgumentPhase
      { projekt_arguments: serialize_arguments }
    when ProjektPhase::ProjektNotificationPhase
      { projekt_notifications: serialize_notifications }
    when ProjektPhase::LegislationPhase
      { legislation_processes: serialize_legislation_processes }
    when ProjektPhase::PointOfInterestPhase
      { pins: serialize_pins, categories: serialize_categories }
    else
      {}
    end
  end

  def serialize_proposals
    return [] unless projekt_phase.respond_to?(:resources)
    projekt_phase.resources.as_json(only: [:id, :title, :summary, :created_at, :cached_votes_up, :comments_count])
  end

  def serialize_debates
    return [] unless projekt_phase.respond_to?(:resources)
    projekt_phase.resources.as_json(only: [:id, :title, :description, :created_at, :cached_votes_up, :comments_count])
  end

  def serialize_budget
    return nil unless projekt_phase.respond_to?(:budget) && projekt_phase.budget.present?
    projekt_phase.budget.as_json(only: [:id, :name, :phase, :created_at])
  end

  def serialize_polls
    return [] unless projekt_phase.respond_to?(:polls)
    projekt_phase.polls.as_json(only: [:id, :name, :starts_at, :ends_at, :created_at])
  end

  def serialize_livestreams
    return [] unless projekt_phase.respond_to?(:projekt_livestreams)
    projekt_phase.projekt_livestreams.as_json(only: [:id, :title, :url, :starts_at, :created_at])
  end

  def serialize_questions
    return [] unless projekt_phase.respond_to?(:questions)
    projekt_phase.questions.as_json(only: [:id, :title, :created_at, :author_id])
  end

  def serialize_formular
    return nil unless projekt_phase.respond_to?(:formular) && projekt_phase.formular.present?
    projekt_phase.formular.as_json(only: [:id, :created_at])
  end

  def serialize_events
    return [] unless projekt_phase.respond_to?(:projekt_events)
    projekt_phase.projekt_events.as_json(only: [:id, :title, :starts_at, :ends_at, :created_at])
  end

  def serialize_arguments
    return [] unless projekt_phase.respond_to?(:projekt_arguments)
    projekt_phase.projekt_arguments.as_json(only: [:id, :title, :created_at])
  end

  def serialize_notifications
    return [] unless projekt_phase.respond_to?(:projekt_notifications)
    projekt_phase.projekt_notifications.as_json(only: [:id, :title, :created_at])
  end

  def serialize_legislation_processes
    return [] unless projekt_phase.respond_to?(:legislation_process) && projekt_phase.legislation_process.present?
    [projekt_phase.legislation_process.as_json(only: [:id, :title, :summary, :created_at])]
  end

  def serialize_pins
    return [] unless projekt_phase.respond_to?(:projekt_point_of_interest_pins)
    projekt_phase.projekt_point_of_interest_pins.map do |pin|
      pin_data = pin.as_json(only: [:id, :projekt_point_of_interest_category_id, :author_id, :created_at, :updated_at])

      if pin.map_location.present?
        pin_data[:map_location] = {
          latitude: pin.map_location.latitude,
          longitude: pin.map_location.longitude,
          zoom: pin.map_location.zoom
        }
      end

      pin_data
    end
  end

  def serialize_categories
    return [] unless projekt_phase.respond_to?(:projekt_point_of_interest_categories)
    projekt_phase.projekt_point_of_interest_categories.as_json(
      only: [:id, :name, :color, :icon, :position, :created_at, :updated_at]
    )
  end

  def self.serialize_collection(projekt_phases)
    projekt_phases.map { |phase| new(phase).serialize }
  end
end

