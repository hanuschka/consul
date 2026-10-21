class SimilarContributions::Find < ApplicationService
  def initialize(resource, relation:, limit:, feature:, projekt_phase:)
    @resource = resource
    @relation = relation
    @limit = limit
    @feature = feature
    @projekt_phase = projekt_phase
  end

  def call
    return [] unless SimilarContributions::Scopes.enabled_for?(projekt_phase)
    return [] unless Ai::Settings.ai_available?

    candidates = SimilarContributions::CandidateQuery.call(relation, resource).to_a
    return [] if candidates.empty?

    SimilarContributions::Ranking.call(
      candidates,
      title: resource.title,
      description: resource.description,
      limit: limit,
      feature: feature,
      projekt_phase: projekt_phase
    )
  end

  private

    attr_reader :resource, :relation, :limit, :feature, :projekt_phase
end
