class SimilarContributions::FindForPhase < ApplicationService
  MATCH_LIMIT = 3
  USAGE_FEATURE = "similar_contributions.find_for_phase".freeze

  def initialize(resource, projekt_phase: nil)
    @resource = resource
    @projekt_phase = projekt_phase || resource.projekt_phase
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

    attr_reader :resource, :projekt_phase

    def fetch_candidates
      relation = SimilarContributions::Scopes.phase_relation(resource, projekt_phase)

      SimilarContributions::CandidateQuery.call(
        relation,
        title: resource.title,
        description: resource.description,
        excluded_id: resource.id
      ).to_a
    end
end
