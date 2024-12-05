class Api::ApiClientsRegistrationController < Api::BaseController
  def mark_as_registered
    @api_client.mark_as_registered!(params[:api_token])
  end
end
