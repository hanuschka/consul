class SimilarContributions::VectorCandidateQuery < ApplicationService
  # Cosine distance, so 0 is identical and 1 is unrelated. The cut is
  # deliberately loose: it only has to keep obvious noise out of the prompt,
  # because Ranking still has to agree before anything reaches a citizen.
  MAX_DISTANCE = 0.6

  def initialize(relation, resource, vector, limit:)
    @relation = relation
    @resource = resource
    @vector = vector
    @limit = limit
  end

  def call
    candidates = relation
      .joins(join_sql)
      .where("#{distance_sql} <= #{MAX_DISTANCE}")
      .reorder(Arel.sql(distance_sql))
      .limit(limit)

    candidates = candidates.where.not(id: resource.id) if resource.id.present?

    candidates
  end

  private

    attr_reader :relation, :resource, :vector, :limit

    def join_sql
      <<~SQL
        INNER JOIN similar_contribution_embeddings similar_embeddings
          ON similar_embeddings.contribution_type = #{quote(contribution_type)}
         AND similar_embeddings.contribution_id = #{relation.klass.quoted_table_name}.id
      SQL
    end

    def distance_sql
      "similar_embeddings.embedding <=> #{quote(vector)}::vector"
    end

    def contribution_type
      relation.klass.base_class.name
    end

    def quote(value)
      relation.klass.connection.quote(value)
    end
end
