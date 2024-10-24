class Api::BaseController < ActionController::Base
  class UnauthentificatedError < StandardError; end

  include GlobalizeFallbacks
  include AccessDeniedHandler

  before_action :find_api_client
  rescue_from UnauthentificatedError, with: :render_unauthentificated

  private

  def bearer_token
    pattern = /^Bearer /
    header  = request.headers["Authorization"]

    if header&.match(pattern)
      header.gsub(pattern, "")
    end
  end

  def find_api_client
    @api_client = ApiClient.find_by!(auth_token: bearer_token)

    if @api_client.nil?
      raise UnauthentificatedError
    end
  end

  def current_api_client
    @api_client
  end

   def render_unauthentificated
    render json: {
      error: 'You need to log in to access this resource'
    }, status: :unauthorized
  end
end
