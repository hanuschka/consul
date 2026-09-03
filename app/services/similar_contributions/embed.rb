class SimilarContributions::Embed < ApplicationService
  MODEL = "text-embedding-3-small".freeze
  USAGE_FEATURE = "similar_contributions.embed".freeze
  BATCH_SIZE = 96

  def initialize(resources)
    @resources = Array(resources)
  end

  # Vector retrieval is only ever an optimisation over text search, so an
  # unavailable store or provider is not an error here -- the caller reads a
  # zero count as "no vectors" and falls back.
  def self.available?
    SimilarContributionEmbedding.store_available? &&
      Ai::Settings.ai_available? &&
      Ai::RubyLlmFactory.embeddable?
  end

  # Stores a current vector for every resource whose text has changed, and
  # answers how many of them that was. Only the digests are read back, never
  # the vectors: at 256 dimensions a batch of stored vectors is hundreds of
  # kilobytes of text to parse for an answer nobody asked for.
  def call
    return 0 if resources.empty?
    return 0 unless self.class.available?

    stale = resources.reject { |resource| stored_digests[key_for(resource)] == digest_for(resource) }

    stale.each_slice(BATCH_SIZE) { |batch| embed_batch(batch) }

    stale.size
  end

  private

    attr_reader :resources

    def stored_digests
      @stored_digests ||= SimilarContributionEmbedding
        .where(contribution_type: contribution_types, contribution_id: resources.map(&:id))
        .pluck(:contribution_type, :contribution_id, :source_digest)
        .to_h { |type, id, digest| [[type, id], digest] }
    end

    def embed_batch(batch)
      embedding = Ai::RubyLlmFactory.embed(
        batch.map { |resource| text_for(resource) },
        model: MODEL,
        dimensions: SimilarContributionEmbedding::DIMENSIONS,
        feature: USAGE_FEATURE
      )

      store(batch.zip(normalize(embedding.vectors, batch.size)))
    end

    # A single input comes back as one flat vector rather than a list of one.
    def normalize(vectors, expected_size)
      return vectors if expected_size > 1

      vectors.first.is_a?(Array) ? vectors : [vectors]
    end

    def store(pairs)
      values = pairs.map do |resource, vector|
        type, id = key_for(resource)

        "(#{quote(type)}, #{id.to_i}, " \
          "#{quote(SimilarContributionEmbedding.to_sql_literal(vector))}::vector, " \
          "#{quote(digest_for(resource))}, #{quote(MODEL)}, NOW(), NOW())"
      end

      SimilarContributionEmbedding.connection.execute(<<~SQL)
        INSERT INTO similar_contribution_embeddings
          (contribution_type, contribution_id, embedding, source_digest, model, created_at, updated_at)
        VALUES #{values.join(", ")}
        ON CONFLICT (contribution_type, contribution_id) DO UPDATE
          SET embedding = EXCLUDED.embedding,
              source_digest = EXCLUDED.source_digest,
              model = EXCLUDED.model,
              updated_at = EXCLUDED.updated_at
      SQL
    end

    def contribution_types
      @contribution_types ||= resources.map { |resource| resource.class.base_class.name }.uniq
    end

    def key_for(resource)
      [resource.class.base_class.name, resource.id]
    end

    def text_for(resource)
      texts[resource] ||= SimilarContributions::EmbeddingText.for(resource)
    end

    def digest_for(resource)
      digests[resource] ||= SimilarContributions::EmbeddingText.digest(text_for(resource))
    end

    def texts
      @texts ||= {}
    end

    def digests
      @digests ||= {}
    end

    def quote(value)
      SimilarContributionEmbedding.connection.quote(value)
    end
end
