class SimilarContributions::SubjectVector < ApplicationService
  def initialize(resource)
    @resource = resource
  end

  # The one vector a retrieval actually has to read back, kept apart from Embed
  # so that storing vectors in bulk never pays for parsing them.
  def call
    return if !SimilarContributions::Embed.available?

    SimilarContributions::Embed.call(resource)

    stored_vector
  end

  private

    attr_reader :resource

    def stored_vector
      SimilarContributionEmbedding
        .where(contribution_type: resource.class.base_class.name, contribution_id: resource.id)
        .pick(Arel.sql("embedding::text"))
    end
end
