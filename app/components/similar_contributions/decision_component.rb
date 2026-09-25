class SimilarContributions::DecisionComponent < ApplicationComponent
  include SimilarContributionsCheckState

  MATCHES_ID = "similar-contributions-decision-matches".freeze
  SURFACE = "decision".freeze

  attr_reader :resource, :matches

  def initialize(resource, matches: [])
    @resource = resource
    @matches = Array(matches)
  end
end
