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
    projekts_relation(resource, Array(projekt))
  end

  # Every contribution of the resource's class inside a set of projekts, with
  # nothing filtered out and nothing preloaded: the base of every relation that
  # reaches past the phase, and on its own what an id has to be resolved
  # through -- a row the list shows must stay addressable even once retired.
  def projekts_contributions(resource, projekts)
    projekt_ids = Array(projekts).map(&:id)

    return resource.class.none if projekt_ids.empty?

    phase_ids = ::ProjektPhase.where(projekt_id: projekt_ids).select(:id)

    case resource
    when ::Proposal
      ::Proposal.where(projekt_phase_id: phase_ids)
    when ::Budget::Investment
      ::Budget::Investment.where(budget_id: ::Budget.where(projekt_phase_id: phase_ids).select(:id))
    else
      resource.class.none
    end
  end

  # The same set as an admin row renders it. Still unfiltered: the row labels a
  # retired or unfeasible entry as such rather than dropping it.
  def projekts_presentation_relation(resource, projekts)
    projekts_contributions(resource, projekts)
      .includes(phase_includes_for(resource.class.base_class), *PRESENTATION_INCLUDES)
  end

  # What a search may offer as a match, which is narrower than what a list may
  # show: a draft, archived or retired proposal must never be proposed as the
  # thing a new contribution duplicates.
  def projekts_relation(resource, projekts)
    relation = projekts_presentation_relation(resource, projekts)

    return relation if !resource.is_a?(::Proposal)

    relation.base_selection
  end

  # Where the exclusion action resolves the id it was handed. Unfiltered on
  # purpose: a row a staff list shows must stay addressable, and a match from
  # one of the further projekts would not be found in the current one at all.
  def excludable_relation(resource, projekt_phase)
    projekts_contributions(resource, searched_projekts(projekt_phase))
  end

  # The projekts a phase's staff-side check covers: its own plus the further
  # ones selected on it, the no longer published among those already dropped.
  def searched_projekts(projekt_phase)
    return [] if projekt_phase.blank?

    [projekt_phase.projekt] + projekt_phase.published_similar_search_projekts.to_a
  end

  # A budget investment is answered by its valuator, a proposal by an admin, so
  # the text a match was already given comes from a different column per class.
  def answer_of(resource)
    resource.is_a?(::Budget::Investment) ? resource.valuator_explanation : resource.official_answer
  end
end
