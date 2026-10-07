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

      Rails.logger.warn("[Whatsapp] webhook delivery refused: #{refusal_reason}")

      head :unauthorized
    end

    # A configured signing secret makes the signature mandatory on top of the
    # shared secret, so a leaked header value alone can no longer forge a
    # delivery. The cost is that a wrong signing secret refuses every delivery
    # until it is fixed; 360dialog retries them, and #refusal_reason says why.
    def authenticated?
      return false if signature_required? && !valid_signature?

      valid_url_secret? || valid_header_secret?
    end

    def signature_required?
      ::Whatsapp.webhook_signature_secret.present?
    end

    def refusal_reason
      if signature_required? && provided_signature.blank?
        "no x-360dialog-signature header"
      elsif signature_required? && !valid_signature?
        "signature does not match whatsapp.webhook_signature_secret"
      else
        "no valid webhook_secret header or url_secret"
      end
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

    # Checked before the digest is computed rather than left to #matches?: an HMAC
    # over an empty key is a perfectly valid digest, so without a secret anyone
    # could sign a forged delivery with nothing and have it pass.
    def valid_signature?
      return false if ::Whatsapp.webhook_signature_secret.blank?

      matches?(provided_signature, expected_signature)
    end

    def provided_signature
      request.headers[SIGNATURE_HEADER].to_s.sub(SIGNATURE_PREFIX, "")
    end

    # Signed over the raw body: re-serializing the parsed JSON would change the
    # bytes and never match.
    def expected_signature
      OpenSSL::HMAC.hexdigest(
        "SHA256", ::Whatsapp.webhook_signature_secret, request.raw_post
      )
    end

    def matches?(provided_secret, expected_secret)
      return false if provided_secret.blank?
      return false if expected_secret.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_secret.to_s, expected_secret.to_s)
    end
end
