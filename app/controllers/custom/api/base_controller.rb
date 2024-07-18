class Api::BaseController < ActionController::Base
  include GlobalizeFallbacks
  include AccessDeniedHandler

  before_action :find_api_client

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
  end

  def current_api_client
    @api_client
  end
end
