class WhatsappApi::BaseController < ActionController::API
  AUTH_HEADER = "HTTP_D360_API_KEY".freeze
  SIGNATURE_HEADER = "HTTP_X_360DIALOG_SIGNATURE".freeze
  SIGNATURE_PREFIX = /\Asha256=/

  before_action :ensure_feature_enabled!
  before_action :authenticate_webhook!

  private

    def ensure_feature_enabled!
      return if ::Whatsapp.enabled?

      head :not_found
    end

    def authenticate_webhook!
      return if authenticated?

      head :unauthorized
    end

    # The shared secret is only accepted while no signing secret is configured:
    # a static header any intermediary can replay is the weaker of the two.
    def authenticated?
      return valid_signature? if ::Whatsapp.webhook_signature_secret.present?

      valid_secret?(request.headers[AUTH_HEADER])
    end

    def valid_secret?(provided_secret)
      return false if provided_secret.blank?

      ActiveSupport::SecurityUtils.secure_compare(
        provided_secret.to_s, ::Whatsapp.webhook_secret.to_s
      )
    end

    def valid_signature?
      provided_signature = request.headers[SIGNATURE_HEADER].to_s.sub(SIGNATURE_PREFIX, "")

      return false if provided_signature.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_signature, expected_signature)
    end

    # Signed over the raw body: re-serializing the parsed JSON would change the
    # bytes and never match.
    def expected_signature
      OpenSSL::HMAC.hexdigest(
        "SHA256", ::Whatsapp.webhook_signature_secret.to_s, request.raw_post
      )
    end
end
