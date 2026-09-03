class SimilarContributions::FindForProjekt < ApplicationService
  MATCH_LIMIT = 5
  USAGE_FEATURE = "similar_contributions.find_for_projekt".freeze

  def initialize(resource)
    @resource = resource
    @projekt_phase = resource.projekt_phase
    @projekt = @projekt_phase&.projekt
  end

  def call
    return [] unless SimilarContributions::Scopes.enabled_for?(projekt_phase)
    return [] unless Ai::Settings.ai_available?

    candidates = fetch_candidates
    return [] if candidates.empty?

    SimilarContributions::Ranking.call(
      candidates,
      title: resource.title,
      description: resource.description,
      limit: MATCH_LIMIT,
      feature: USAGE_FEATURE,
      projekt_phase: projekt_phase
    )
  end

  private

    attr_reader :resource, :projekt_phase, :projekt

    def fetch_candidates
      relation = SimilarContributions::Scopes.projekt_relation(resource, projekt)

      SimilarContributions::CandidateQuery.call(relation, resource).to_a
    end
end
