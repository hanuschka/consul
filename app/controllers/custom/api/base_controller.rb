class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  class ForbiddenError < StandardError; end
  class UnauthorizedError < StandardError; end

  before_action :authenticate_api_client!
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ForbiddenError, with: :render_forbidden
  rescue_from UnauthorizedError, with: :render_unauthorized

  private

  def authenticate_api_client!
    token = request.headers['Authorization']&.split(' ')&.last
    client = ApiClient.find_by(auth_token: token)

    if client.present?
      @current_client = client
    else
      raise UnauthorizedError, 'Invalid or missing API token.'
    end
  end

  def current_client
    @current_client
  end

  def check_read_access!
    unless current_client&.can_read_public_data?
      raise ForbiddenError, 'You do not have permission to read this resource.'
    end
  end

  def check_admin_access!
    unless current_client&.admin?
      raise ForbiddenError, 'You do not have permission to perform this action. Admin access required.'
    end
  end

  def render_forbidden(exception)
    render json: {
      error: {
        type: "forbidden",
        messages: exception.message
      }
    }, status: :forbidden
  end

  def render_unauthorized(exception)
    render json: {
      error: {
        type: "unauthorized",
        messages: exception.message
      }
    }, status: :unauthorized
  end

  def render_not_found
    render json: {
      error: { type: "not_found", messages: ["Not found"]}
    }, status: 404
  end
end
