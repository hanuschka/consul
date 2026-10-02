class SimilarContributions::RecheckAdditionalProjektsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  # One ranking per published contribution of the phase, so it runs where a
  # timeout is a retry rather than a failed request -- the admin is told the
  # matches appear as they are found.
  def perform(projekt_phase)
    SimilarContributions::RecheckAdditionalProjekts.call(projekt_phase)
  end
end
