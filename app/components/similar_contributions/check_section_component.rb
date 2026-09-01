class SimilarContributions::CheckSectionComponent < ApplicationComponent
  POLL_INTERVAL = 1000
  POLL_TIMEOUT = 20_000

  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end

  def render?
    resource.present? && resource.persisted? && resource.similar_contributions_check_processing?
  end

  def status_url
    if investment?
      similar_contributions_status_budget_investment_path(resource.budget, resource)
    else
      similar_contributions_status_proposal_path(resource)
    end
  end

  def publish_url
    if investment?
      publish_draft_budget_investment_path(resource.budget, resource)
    else
      publish_draft_proposal_path(resource)
    end
  end

  private

    def investment?
      resource.is_a?(::Budget::Investment)
    end
end
