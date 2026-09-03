class SimilarContributions::ListComponent < ApplicationComponent
  ANSWER_EXCERPT_LENGTH = 300

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

  def processing_status_for(resource)
    if resource.is_a?(::Budget::Investment)
      investment_status(resource)
    else
      proposal_status(resource)
    end
  end

  def created_at_for(resource)
    l(resource.created_at, format: :long)
  end

  def answer_excerpt_for(resource)
    attribute = SimilarContributions::Scopes.answer_attribute(resource)
    answer = resource.public_send(attribute)

    return if answer.blank?

    SimilarContributions::SearchTerms.strip_html(answer).squish.truncate(ANSWER_EXCERPT_LENGTH)
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

  private

    def investment_status(investment)
      return t(".status.unfeasible") if investment.unfeasible?
      return t(".status.answered") if investment.valuation_finished?

      t(".status.open")
    end

    def proposal_status(proposal)
      return t(".status.retired") if proposal.retired?
      return t(".status.answered") if proposal.official_answer.present?

      t(".status.open")
    end
end
