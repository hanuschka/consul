class WhatsappApi::BaseController < ActionController::API
  AUTH_HEADER = "HTTP_D360_API_KEY".freeze

  before_action :ensure_feature_enabled!
  before_action :authenticate_webhook!

  private

    def ensure_feature_enabled!
      return if ::Whatsapp.enabled?

      head :not_found
    end

    def authenticate_webhook!
      return if valid_secret?(request.headers[AUTH_HEADER])
      return if valid_secret?(params[:secret])

      head :unauthorized
    end

    def valid_secret?(provided_secret)
      return false if provided_secret.blank?

      ActiveSupport::SecurityUtils.secure_compare(
        provided_secret.to_s, ::Whatsapp.webhook_secret.to_s
      )
    end
end
