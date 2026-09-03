module SimilarContributions::Scopes
  SETTING_KEY = "general.similar_contributions_check".freeze

  # Everything the admin list renders per match is preloaded here, because the
  # matches reach the component as records this relation already loaded. Every
  # readable string on the row is a Globalize attribute, so the translations sit
  # in their own tables and each one left out costs a query per distinct record.
  PRESENTATION_INCLUDES = [
    :translations,
    { sentiment: :translations },
    { projekt_labels: :translations },
    { image: { attachment_attachment: :blob } }
  ].freeze

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

  # The phase a row names and links to, plus the projekt behind it that decides
  # who may follow that link. Reached through a different association per class,
  # so it cannot join PRESENTATION_INCLUDES.
  def phase_includes_for(contribution_class)
    if contribution_class <= ::Budget::Investment
      { budget: { projekt_phase: [:projekt, :translations] } }
    else
      { projekt_phase: [:projekt, :translations] }
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
        .includes(phase_includes_for(::Proposal), *PRESENTATION_INCLUDES)
    when ::Budget::Investment
      ::Budget::Investment
        .where(budget_id: projekt.budgets.select(:id))
        .includes(phase_includes_for(::Budget::Investment), *PRESENTATION_INCLUDES)
    else
      resource.class.none
    end
  end

  # A budget investment is answered by its valuator, a proposal by an admin, so
  # the text a match was already given comes from a different column per class.
  def answer_of(resource)
    resource.is_a?(::Budget::Investment) ? resource.valuator_explanation : resource.official_answer
  end
end
