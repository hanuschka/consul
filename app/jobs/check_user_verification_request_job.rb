class CheckUserVerificationRequestJob < ApplicationJob
  def perform(file)
    Verifications::CheckXML.check_verification_request(file)
  end
end
