class SimilarContributions::CandidateCounts < ApplicationService
  MINIMUM_RANK = 0.2
  MAX_EXAMINED_CANDIDATES = 50

  def initialize(resources)
    @resources = Array(resources)
  end

  def call
    return {} unless Ai::Settings.ai_available?

    counts = {}

    resources_by_projekt.each do |projekt, projekt_resources|
      counts.merge!(count_within(projekt, projekt_resources))
    end

    counts
  end

  private

    attr_reader :resources

    def resources_by_projekt
      countable_resources.group_by { |resource| projekt_phase_of(resource).projekt }
    end

    def countable_resources
      @countable_resources ||= resources.select do |resource|
        projekt_phase = projekt_phase_of(resource)

        resource.persisted? &&
          projekt_phase&.projekt.present? &&
          SimilarContributions::Scopes.enabled_for?(projekt_phase) &&
          tsquery_for(resource).present?
      end
    end

    def projekt_phase_of(resource)
      SimilarContributions::Scopes.projekt_phase_of(resource)
    end

    def count_within(projekt, projekt_resources)
      sql = counting_sql(projekt, projekt_resources)

      ActiveRecord::Base.connection.select_rows(sql).to_h do |resource_id, count|
        [resource_id.to_i, count.to_i]
      end
    end

    def counting_sql(projekt, projekt_resources)
      table = projekt_resources.first.class.table_name

      <<~SQL
        WITH scoped_candidates AS (
          SELECT id, tsv FROM #{table}
          WHERE id IN (#{candidate_ids_sql(projekt, projekt_resources.first)})
        )
        SELECT subjects.id, matches.total
        FROM (VALUES #{subject_values(projekt_resources)}) AS subjects(id, tsquery_string)
        LEFT JOIN LATERAL (
          SELECT COUNT(*) AS total
          FROM (
            SELECT candidates.tsv
            FROM scoped_candidates candidates
            WHERE candidates.id <> subjects.id
              AND candidates.tsv @@ to_tsquery(#{quoted_dictionary}, unaccent(subjects.tsquery_string))
            LIMIT #{MAX_EXAMINED_CANDIDATES}
          ) examined
          WHERE ts_rank(
                  examined.tsv,
                  to_tsquery(#{quoted_dictionary}, unaccent(subjects.tsquery_string))
                ) >= #{MINIMUM_RANK}
        ) matches ON TRUE
      SQL
    end

    def subject_values(projekt_resources)
      projekt_resources.map do |resource|
        "(#{resource.id.to_i}, #{quote(tsquery_for(resource))})"
      end.join(", ")
    end

    def candidate_ids_sql(projekt, sample_resource)
      SimilarContributions::Scopes
        .projekt_relation(sample_resource, projekt)
        .except(:includes)
        .select(:id)
        .to_sql
    end

    def tsquery_for(resource)
      SimilarContributions::SearchTerms.tsquery_string(resource.title, resource.description)
    end

    def quoted_dictionary
      quote(SearchDictionarySelector.call)
    end

    def quote(value)
      ActiveRecord::Base.connection.quote(value)
    end
end
