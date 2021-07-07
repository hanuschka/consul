class CheckUserVerificationRequestJob < ApplicationJob
  queue_as :default
  retry_on Errno::ENOENT, wait: 3.seconds, attempts: 10

  def perform(*args)
    Verifications:: CheckXML.check_verification_request
  end
end
