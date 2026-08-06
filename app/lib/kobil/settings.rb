module Kobil::Settings
  REQUIRED_CREDENTIAL_KEYS = %i[issuer client_id client_secret redirect_uri].freeze

  def self.missing_required_credential_keys
    REQUIRED_CREDENTIAL_KEYS.reject { |key| credential(key).present? }
  end

  def self.credential(key)
    Rails.application.secrets.dig(:kobil, key)
  end
end
