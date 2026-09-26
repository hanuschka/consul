class SimilarContributions::EmbedJob < ApplicationJob
  queue_as :default

  # Cheap when nothing changed: Embed compares the text digest first and only
  # calls the provider for contributions whose stored vector is stale.
  def perform(resource)
    SimilarContributions::Embed.call(resource)
  end
end
