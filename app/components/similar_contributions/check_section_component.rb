class SimilarContributions::CheckSectionComponent < ApplicationComponent
  include SimilarContributionsCheckState

  MODAL_ID = "similar-contributions-notice"

  POLL_INTERVAL = 1000
  POLL_TIMEOUT = 20_000

  attr_reader :resource

  def initialize(resource, embbeded_in_ai_flow: false)
    @resource = resource
    @embbeded_in_ai_flow = embbeded_in_ai_flow
  end

  def form_id
    helpers.dom_id(resource, :form)
  end

  def ai_flow?
    @embbeded_in_ai_flow
  end

  def status_url
    if investment?
      similar_contributions_status_budget_investment_path(resource.budget, resource)
    else
      similar_contributions_status_proposal_path(resource)
    end
  end

  # Getting past the check means publishing on the ordinary form, but only
  # moving on to the next step in the AI flow, which decides for itself whether
  # an evaluation still stands between the draft and publication.
  def publish_url
    return ai_flow_publish_url if ai_flow?

    if investment?
      publish_draft_budget_investment_path(resource.budget, resource)
    else
      publish_draft_proposal_path(resource)
    end
  end

  private

    def ai_flow_publish_url
      if investment?
        generate_budget_investment_publish_checked_path(resource)
      else
        generate_proposal_publish_checked_path(resource)
      end
    end

    def investment?
      resource.is_a?(::Budget::Investment)
    end
end
