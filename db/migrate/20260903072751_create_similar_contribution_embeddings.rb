class CreateSimilarContributionEmbeddings < ActiveRecord::Migration[6.1]
  # pgvector is a server package, not a gem, and it is not built for
  # PostgreSQL 12 -- which some tenants still run. Raising here would break
  # their deploys, so the table is skipped and the application falls back to
  # text-search retrieval. Run similar_contributions:install_embeddings once
  # the extension is available.
  def up
    result = SimilarContributionEmbeddingsInstaller.install(connection)

    return if result != :unavailable

    say "pgvector is unavailable on PostgreSQL " \
        "#{SimilarContributionEmbeddingsInstaller.server_major_version(connection)}; " \
        "skipping #{SimilarContributionEmbeddingsInstaller::TABLE_NAME}. " \
        "Similar-contribution retrieval stays on text search until " \
        "rails similar_contributions:install_embeddings runs."
  end

  def down
    drop_table SimilarContributionEmbeddingsInstaller::TABLE_NAME, if_exists: true
  end
end
