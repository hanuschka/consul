class SimilarContributions::CheckJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(resource)
    matches = SimilarContributions::FindForPhase.call(resource)

    resource.update_columns(
      similar_contributions_matches: matches.map { |match| serialized(match) },
      similar_contributions_check_status: "completed"
    )
  rescue StandardError => e
    Rails.logger.error("[SimilarContributions] check failed for " \
                       "#{resource.class}##{resource.id}: #{e.class} - #{e.message}")

    resource.update_columns(similar_contributions_check_status: "failed")
  end

  private

    def serialized(match)
      {
        "id" => match.resource.id,
        "relevance" => match.relevance,
        "reason" => match.reason
      }
    end
end
