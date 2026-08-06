class WhatsappApi::BaseController < ActionController::API
  # 360dialog forwards a different one of these depending on how the account was
  # onboarded, and stores every header it is given either way, so the value is
  # accepted under whichever name actually arrives.
  AUTH_HEADERS = %w[HTTP_D360_API_KEY HTTP_AUTHORIZATION].freeze
  SIGNATURE_HEADER = "HTTP_X_360DIALOG_SIGNATURE".freeze
  SIGNATURE_PREFIX = /\Asha256=/
  BEARER_PREFIX = /\ABearer\s+/i

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

    # Any one of the three is enough. Gating the others behind a configured
    # signing secret looks stricter but means a single unused credential in
    # secrets.yml silently rejects every delivery — an outage, not a defence.
    def authenticated?
      valid_signature? || valid_url_secret? || valid_header_secret?
    end

    def valid_header_secret?
      AUTH_HEADERS.any? do |header|
        provided_secret = request.headers[header].to_s.sub(BEARER_PREFIX, "")

        matches?(provided_secret, ::Whatsapp.webhook_secret)
      end
    end

    def valid_url_secret?
      matches?(params[:url_secret], ::Whatsapp.url_secret)
    end

    def valid_signature?
      provided_signature = request.headers[SIGNATURE_HEADER].to_s.sub(SIGNATURE_PREFIX, "")

      matches?(provided_signature, expected_signature)
    end

    # Signed over the raw body: re-serializing the parsed JSON would change the
    # bytes and never match.
    def expected_signature
      OpenSSL::HMAC.hexdigest(
        "SHA256", ::Whatsapp.webhook_signature_secret.to_s, request.raw_post
      )
    end

    def matches?(provided_secret, expected_secret)
      return false if provided_secret.blank?
      return false if expected_secret.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_secret.to_s, expected_secret.to_s)
    end
end
