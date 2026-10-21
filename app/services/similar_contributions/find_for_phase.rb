class SimilarContributions::FindForPhase < ApplicationService
  MATCH_LIMIT = 3
  USAGE_FEATURE = "similar_contributions.find_for_phase".freeze

  def initialize(resource, projekt_phase: nil)
    @resource = resource
    @projekt_phase = projekt_phase || resource.projekt_phase
  end

  def call
    SimilarContributions::Find.call(
      resource,
      relation: SimilarContributions::Scopes.phase_relation(resource, projekt_phase),
      limit: MATCH_LIMIT,
      feature: USAGE_FEATURE,
      projekt_phase: projekt_phase
    )
  end

  private

    attr_reader :resource, :projekt_phase
end
