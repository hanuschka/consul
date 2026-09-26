class SimilarContributions::StoredMatches < ApplicationService
  def initialize(resource)
    @resource = resource
  end

  def call
    return [] if entries.empty?

    matched_by_id = matched_resources.index_by(&:id)

    entries.filter_map do |entry|
      matched = matched_by_id[entry["id"].to_i]
      next if matched.nil?

      SimilarContributions::Ranking::Match.new(
        resource: matched,
        relevance: entry["relevance"].to_i,
        reason: entry["reason"]
      )
    end
  end

  private

    attr_reader :resource

    def entries
      @entries ||= resource.stored_similar_contributions_matches
    end

    # Re-reads through the phase scope rather than by bare id, so a match that
    # was hidden or retired after the check ran drops out instead of being
    # offered to the citizen.
    def matched_resources
      projekt_phase = SimilarContributions::Scopes.projekt_phase_of(resource)

      SimilarContributions::Scopes
        .phase_relation(resource, projekt_phase)
        .where(id: entries.map { |entry| entry["id"].to_i })
    end
end
