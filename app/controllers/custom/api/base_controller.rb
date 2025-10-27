class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_api_client!
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def authenticate_api_client!
    token = request.headers['Authorization']&.split(' ')&.last
    client = ApiClient.find_by(auth_token: token)

    if client.present?
      @current_client = client
    else
      render json: {
        error: {
          type: "unauthorized",
          messages: 'Invalid or missing API token.'
        }
      }, status: :unauthorized
    end
  end

  def render_not_found
    render json: {
      error: { type: "not_found", messages: ["Not found"]}
    }, status: 404
  end
end
