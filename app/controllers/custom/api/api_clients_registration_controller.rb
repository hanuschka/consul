class Api::ApiClientsRegistrationController < Api::BaseController
  skip_forgery_protection

  def mark_as_registered
    @api_client.registered!
  end
end
