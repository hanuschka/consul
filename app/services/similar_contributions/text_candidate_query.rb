class SimilarContributions::TextCandidateQuery < ApplicationService
  def initialize(relation, resource, limit:)
    @relation = relation
    @resource = resource
    @limit = limit
  end

  def call
    return relation.none if search_terms.blank?

    candidates = relation.pg_search_any_word(search_terms).limit(limit)
    candidates = candidates.where.not(id: resource.id) if resource.id.present?

    candidates
  end

  private

    attr_reader :relation, :resource, :limit

    def search_terms
      @search_terms ||= SimilarContributions::SearchTerms
        .query_string(resource.title, resource.description)
    end
end
