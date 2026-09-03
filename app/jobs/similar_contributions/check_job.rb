class SimilarContributions::CheckJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  # The status is written before the exception goes on, so the citizen waiting
  # on the modal is released -- but the failure still reaches the worker, where
  # it is retried and recorded in delayed_jobs.last_error. Swallowing it here
  # made a broken check indistinguishable from one that found nothing.
  def perform(resource)
    matches = SimilarContributions::FindForPhase.call(resource)

    resource.update_columns(
      similar_contributions_matches: matches.map { |match| serialized(match) },
      similar_contributions_check_status: "completed"
    )
  rescue StandardError
    resource.update_columns(similar_contributions_check_status: "failed")

    raise
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
