class SimilarContributions::RecordGroupJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  # Runs after a contribution is published rather than at check time: a draft
  # the citizen walks away from is pruned, and its matches must not pull the
  # contributions it resembled into a set nobody submitted.
  #
  # Nothing is rescued: a failure belongs in delayed_jobs.last_error, where it
  # is retried and visible, not in a log line beside an empty result.
  def perform(resource)
    SimilarContributions::RecordGroup.call(resource, matches_for(resource))
  end

  private

    # A contribution the check already examined keeps its answer, empty
    # included -- only one that never ran a check pays for a second look.
    def matches_for(resource)
      return SimilarContributions::StoredMatches.call(resource) if resource.similar_contributions_check_finished?

      SimilarContributions::FindForPhase.call(resource)
    end
end
