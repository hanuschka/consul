class SimilarContributionEmbedding < ApplicationRecord
  DIMENSIONS = SimilarContributionEmbeddingsInstaller::DIMENSIONS

  belongs_to :contribution, polymorphic: true

  validates :source_digest, presence: true
  validates :model, presence: true

  # pgvector is installed per server, so a host can legitimately be running
  # without this table. Retrieval asks before it builds a vector query and
  # falls back to text search when the answer is no.
  def self.store_available?
    return @store_available if defined?(@store_available)

    @store_available = connection.table_exists?(table_name)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    @store_available = false
  end

  def self.to_sql_literal(vector)
    "[#{vector.map { |value| value.to_f.round(8) }.join(",")}]"
  end
end
