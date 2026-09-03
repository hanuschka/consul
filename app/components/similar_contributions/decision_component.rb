class SimilarContributions::DecisionComponent < ApplicationComponent
  include SimilarContributionsCheckState
  include SimilarContributionsSupporting

  MATCHES_ID = "similar-contributions-decision-matches".freeze

  attr_reader :resource, :matches

  def initialize(resource, matches: [])
    @resource = resource
    @matches = Array(matches)
  end

  def votes_container_prefix
    "decision"
  end
end
