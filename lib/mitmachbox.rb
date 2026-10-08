module Mitmachbox
  def self.config
    Rails.application.secrets.mitmachbox || {}
  end

  def self.base_url
    config[:base_url]
  end

  def self.org_id
    config[:org_id]
  end

  def self.client_id
    config[:client_id]
  end

  def self.client_secret
    config[:client_secret]
  end

  def self.participant_key(user_id:, survey_version_id:)
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      Rails.application.secret_key_base,
      "mitmachbox-participant:#{user_id}:#{survey_version_id}"
    )
  end

  def self.configured?
    base_url.present? && org_id.present? && client_id.present? && client_secret.present?
  end
end
