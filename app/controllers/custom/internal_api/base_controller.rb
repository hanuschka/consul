class InternalApi::BaseController < ActionController::API
  class UnauthentificatedError < StandardError; end

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
    @api_client = InternalApiClient.find_by!(auth_token: bearer_token)

    if @api_client.nil?
      raise UnauthentificatedError
    end
  end

  def current_api_client
    @api_client
  end

  # Audit rows written during the action name the system user and carry the
  # internal client in their comment.
  def audit_changes_as_internal_client(&)
    Current.api_client = current_api_client

    ::Audit.as_user(User.system, &)
  ensure
    Current.api_client = nil
  end

  def render_setting_errors(errors)
    render json: {
      error: {
        messages: errors.map { |key, messages| "#{key} #{Array(messages).to_sentence}" },
        details: errors
      }
    }, status: :unprocessable_entity
  end

   def render_unauthentificated
    render json: {
      error: 'You need to log in to access this resource'
    }, status: :unauthorized
  end
end
