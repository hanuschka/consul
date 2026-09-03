class SimilarContributions::ListComponent < ApplicationComponent
  include SimilarContributionsMatchStatus

  attr_reader :matches, :resource

  def initialize(matches, resource:)
    @matches = Array(matches)
    @resource = resource
  end

  def render?
    SimilarContributions::Scopes.enabled_for_resource?(resource)
  end

  def phase_title_for(resource)
    resource.projekt_phase&.title
  end

  def created_at_for(resource)
    l(resource.created_at, format: :long)
  end

  def path_for(resource)
    helpers.similar_contributions_path_for(resource)
  end

  def exclude_path_for(match_resource)
    projekt_phase = SimilarContributions::Scopes.projekt_phase_of(resource)

    if resource.is_a?(::Budget::Investment)
      exclude_similar_contribution_adm_projekts_phase_budget_investment_path(
        projekt_phase, resource, excluded_id: match_resource.id
      )
    else
      exclude_similar_contribution_adm_projekts_phase_proposal_path(
        projekt_phase, resource, excluded_id: match_resource.id
      )
    end
  end
end
