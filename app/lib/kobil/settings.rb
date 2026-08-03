module Kobil::Settings
  REQUIRED_CREDENTIAL_KEYS = %i[issuer client_id client_secret redirect_uri].freeze

  OPTIONAL_CREDENTIAL_KEYS = %i[post_logout_redirect_uri].freeze

  CREDENTIAL_KEYS = (REQUIRED_CREDENTIAL_KEYS + OPTIONAL_CREDENTIAL_KEYS).freeze

  def self.credential_statuses
    CREDENTIAL_KEYS.map do |key|
      {
        key: key,
        configured: credential(key).present?,
        required: REQUIRED_CREDENTIAL_KEYS.include?(key)
      }
    end
  end

  def self.missing_required_credential_keys
    REQUIRED_CREDENTIAL_KEYS.reject { |key| credential(key).present? }
  end

  def self.credential(key)
    Rails.application.secrets.dig(:kobil, key)
  end
end
