class SimilarContributions::CandidateQuery < ApplicationService
  CANDIDATE_LIMIT = 25

  # A persisted contribution always has a title, so reading one back blank means
  # the text is unreachable from here -- in practice a record translated only in
  # another locale, with Globalize's fallbacks missing from the current
  # RequestStore. Returning no candidates for that is indistinguishable from
  # "nothing matched", so it raises instead.
  class UnreadableTitle < StandardError
    def initialize(resource)
      super("#{resource.class}##{resource.id} has no title in locale " \
            "#{I18n.locale} (Globalize fallbacks: #{Globalize.fallbacks.inspect})")
    end
  end

  def initialize(relation, resource, limit: CANDIDATE_LIMIT)
    @relation = relation
    @resource = resource
    @limit = limit
  end

  def call
    raise UnreadableTitle, resource if resource.persisted? && resource.title.blank?

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
