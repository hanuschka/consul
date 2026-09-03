module SimilarContributions::Scopes
  SETTING_KEY = "general.similar_contributions_check".freeze

  # Everything the admin list renders per match is preloaded here, because the
  # matches reach the component as records this relation already loaded.
  PRESENTATION_INCLUDES = [:sentiment, :projekt_labels, { image: { attachment_attachment: :blob } }].freeze

  module_function

  def enabled_for?(projekt_phase)
    projekt_phase.present? && projekt_phase.feature?(SETTING_KEY)
  end

  def enabled_for_resource?(resource)
    enabled_for?(projekt_phase_of(resource))
  end

  def projekt_phase_of(resource)
    if resource.is_a?(::Budget::Investment)
      resource.budget&.projekt_phase
    else
      resource.try(:projekt_phase)
    end
  end

  def phase_relation(resource, projekt_phase)
    case resource
    when ::Proposal
      projekt_phase.proposals.base_selection.includes(:projekt_phase)
    when ::Budget::Investment
      # Citizen-facing, so an already rejected entry must never be offered as
      # something to support instead. The admin list keeps them -- see
      # projekt_relation -- because it labels their processing status.
      projekt_phase.budget&.investments&.not_unfeasible&.includes(budget: :projekt_phase) ||
        ::Budget::Investment.none
    else
      resource.class.none
    end
  end

  def projekt_relation(resource, projekt)
    return resource.class.none if projekt.blank?

    case resource
    when ::Proposal
      ::Proposal
        .where(projekt_phase_id: projekt.projekt_phases.select(:id))
        .base_selection
        .includes(:projekt_phase, *PRESENTATION_INCLUDES)
    when ::Budget::Investment
      ::Budget::Investment
        .where(budget_id: projekt.budgets.select(:id))
        .includes({ budget: :projekt_phase }, *PRESENTATION_INCLUDES)
    else
      resource.class.none
    end
  end

  def answer_attribute(resource)
    resource.is_a?(::Budget::Investment) ? :valuator_explanation : :official_answer
  end
end
