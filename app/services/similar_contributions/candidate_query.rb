class SimilarContributions::CandidateQuery < ApplicationService
  CANDIDATE_LIMIT = 25

  # A persisted contribution always has a title, so reading one back blank
  # means the text is unreachable from here -- in practice a record translated
  # only in another locale, with Globalize's fallbacks missing from the current
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

  # Vectors win when both the subject and some candidates have them; text
  # search stays the fallback, which is what a host without pgvector and a
  # phase whose backfill has not run yet both need.
  def call
    raise UnreadableTitle, resource if resource.persisted? && resource.title.blank?

    vector_candidates.presence || text_candidates
  end

  private

    attr_reader :relation, :resource, :limit

    def vector_candidates
      vector = subject_vector
      return if vector.blank?

      SimilarContributions::VectorCandidateQuery.call(relation, resource, vector, limit: limit).to_a
    end

    def subject_vector
      SimilarContributions::SubjectVector.call(resource)
    end

    def text_candidates
      SimilarContributions::TextCandidateQuery.call(relation, resource, limit: limit)
    end
end
