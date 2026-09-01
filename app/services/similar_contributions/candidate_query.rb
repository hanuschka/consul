class SimilarContributions::CandidateQuery < ApplicationService
  CANDIDATE_LIMIT = 25

  def initialize(relation, title:, description:, excluded_id: nil, limit: CANDIDATE_LIMIT)
    @relation = relation
    @title = title
    @description = description
    @excluded_id = excluded_id
    @limit = limit
  end

  def call
    return relation.none if search_terms.blank?

    candidates = relation.pg_similarity_search(search_terms).limit(limit)
    candidates = candidates.where.not(id: excluded_id) if excluded_id.present?

    candidates
  end

  private

    attr_reader :relation, :title, :description, :excluded_id, :limit

    def search_terms
      @search_terms ||= SimilarContributions::SearchTerms.query_string(title, description)
    end
end
