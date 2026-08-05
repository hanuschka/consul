module Brevo::Settings
  # Everything this integration needs lives in config/secrets.yml under `brevo:` — it is set up
  # once per installation and only this client runs a member instance, so there is no admin
  # surface for it. See config/secrets.yml.example for the block.
  API_BASE_URI = "https://api.brevo.com/v3".freeze

  def self.api_key
    secret(:api_key)
  end

  def self.member_list_id
    secret(:member_list_id)
  end

  def self.webhook_token
    secret(:webhook_token)
  end

  # The site-wide gate (AP1) and the account lifecycle sync (AP2-AP4) are deliberately separate:
  # the instance can be closed to members before the sync is switched on, and the sync can be
  # rehearsed on an open instance without locking anybody out.
  def self.member_instance?
    Rails.application.secrets.dig(:brevo, :member_instance) == true
  end

  def self.sync_enabled?
    api_key.present? && member_list_id.present?
  end

  def self.webhook_enabled?
    sync_enabled? && webhook_token.present?
  end

  def self.secret(key)
    Rails.application.secrets.dig(:brevo, key).presence
  end
  private_class_method :secret
end
