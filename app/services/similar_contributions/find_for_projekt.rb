class SimilarContributions::FindForProjekt < ApplicationService
  MATCH_LIMIT = 5
  USAGE_FEATURE = "similar_contributions.find_for_projekt".freeze

  def initialize(resource)
    @resource = resource
    @projekt_phase = SimilarContributions::Scopes.projekt_phase_of(resource)
  end

  def call
    SimilarContributions::Find.call(
      resource,
      relation: SimilarContributions::Scopes.projekt_relation(resource, projekt_phase&.projekt),
      limit: MATCH_LIMIT,
      feature: USAGE_FEATURE,
      projekt_phase: projekt_phase
    )
  end

  private

    attr_reader :resource, :projekt_phase
end
