# The embedding store needs a server-side extension, which a host can be
# missing (pgvector is not packaged for PostgreSQL 12, which some tenants still
# run). Both the migration and similar_contributions:install_embeddings install
# through here, so a host that gains pgvector later can be brought up to the
# same shape without a new migration.
#
# The table stays out of db/schema.rb on purpose: a schema carrying a
# vector column cannot be loaded at all on a server without the extension,
# which would break setup for every PostgreSQL 12 tenant. This installer is
# the only thing that creates it -- do not commit a dump that includes it.
module SimilarContributionEmbeddingsInstaller
  DIMENSIONS = 256
  TABLE_NAME = "similar_contribution_embeddings".freeze

  module_function

  def install(connection)
    return :unavailable if !extension_available?(connection)
    return :present if connection.table_exists?(TABLE_NAME)

    connection.enable_extension("vector")
    create_table(connection)

    :installed
  end

  def extension_available?(connection)
    connection.select_value("SELECT 1 FROM pg_available_extensions WHERE name = 'vector'").present?
  end

  def server_major_version(connection)
    connection.select_value("SHOW server_version").to_s.split(".").first
  end

  def create_table(connection)
    connection.create_table TABLE_NAME do |t|
      t.references :contribution, null: false, polymorphic: true, index: false
      t.column :embedding, "vector(#{DIMENSIONS})", null: false
      t.string :source_digest, null: false
      t.string :model, null: false

      t.timestamps
    end

    connection.add_index TABLE_NAME,
                         [:contribution_type, :contribution_id],
                         unique: true,
                         name: "index_similar_contribution_embeddings_on_contribution"

    connection.execute(<<~SQL)
      CREATE INDEX index_similar_contribution_embeddings_on_vector
        ON #{TABLE_NAME}
        USING hnsw (embedding vector_cosine_ops)
    SQL
  end
end
