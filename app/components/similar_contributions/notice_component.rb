class SimilarContributions::NoticeComponent < ApplicationComponent
  EXCERPT_LENGTH = 220
  MODAL_ID = "similar-contributions-notice"

  attr_reader :matches, :resource

  def initialize(matches, resource:)
    @matches = Array(matches)
    @resource = resource
  end

  def render?
    matches.any?
  end

  def publish_url
    if resource.is_a?(::Budget::Investment)
      publish_draft_budget_investment_path(resource.budget, resource)
    else
      publish_draft_proposal_path(resource)
    end
  end

  def excerpt_for(match_resource)
    SimilarContributions::SearchTerms
      .strip_html(match_resource.description)
      .squish
      .truncate(EXCERPT_LENGTH)
  end

  def path_for(match_resource)
    if match_resource.is_a?(::Budget::Investment)
      budget_investment_path(match_resource.budget, match_resource)
    else
      proposal_path(match_resource)
    end
  end

  def supporting_available?(match_resource)
    projekt_phase = match_resource.projekt_phase

    return false if projekt_phase.blank?

    projekt_phase_feature?(projekt_phase, "resource.allow_voting")
  end

  def votes_component_for(match_resource)
    if match_resource.is_a?(::Budget::Investment)
      ::Budgets::Investments::VotesComponent.new(match_resource)
    else
      ::Proposals::NewVotesComponent.new(
        match_resource,
        vote_url: vote_proposal_path(match_resource, value: "yes")
      )
    end
  end
end
