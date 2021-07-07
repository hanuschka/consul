class CheckUserVerificationRequestJob < ApplicationJob
  queue_as :default
  retry_on Errno::ENOENT, wait: 4.seconds, attempts: 10, queue: :default, priority: 0

  def perform(*args)
    Verifications:: CheckXML.check_verification_request
  end
end
