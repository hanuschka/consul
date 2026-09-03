class SimilarContributions::NoticeComponent < ApplicationComponent
  SURFACE = "notice".freeze

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
end
