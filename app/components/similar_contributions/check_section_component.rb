class SimilarContributions::CheckSectionComponent < ApplicationComponent
  include SimilarContributionsCheckState

  POLL_INTERVAL = 1000
  POLL_TIMEOUT = 20_000

  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end

  def form_id
    helpers.dom_id(resource, :form)
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
