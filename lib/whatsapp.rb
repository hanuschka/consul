module Whatsapp
  DEFAULT_TRANSCRIPTION_MODEL = "gpt-4o-mini-transcribe".freeze
  DEFAULT_RETENTION_DAYS = 90
  DEFAULT_MAX_VOICE_MEGABYTES = 16
  SERVICE_WINDOW = 24.hours
  WEBHOOK_EVENT_RETENTION = 7.days
  MAX_ICE_BREAKERS = 4
  COMMAND_SEPARATOR = "|".freeze

  def self.config
    Rails.application.secrets.whatsapp || {}
  end

  def self.api_key
    config[:api_key]
  end

  def self.webhook_secret
    config[:webhook_secret]
  end

  # Optional 360dialog platform secret. When present, inbound webhooks are
  # authenticated by an HMAC over the raw body instead of a static shared
  # secret, which a leaked log line can no longer expose.
  def self.webhook_signature_secret
    config[:webhook_signature_secret]
  end

  def self.base_url
    config[:url]
  end

  def self.business_number
    config[:business_number].to_s.gsub(/\D/, "")
  end

  REQUIRED_CREDENTIAL_KEYS = %i[url api_key webhook_secret].freeze

  def self.missing_required_credential_keys
    REQUIRED_CREDENTIAL_KEYS.reject { |key| config[key].present? }
  end

  def self.configured?
    missing_required_credential_keys.empty?
  end

  def self.enabled?
    Setting["feature.whatsapp_bot"].present? && configured?
  end

  def self.deep_link_url(prefilled_text)
    return if business_number.blank?

    "https://wa.me/#{business_number}?text=#{CGI.escape(prefilled_text.to_s)}"
  end

  # The chat text a scanned QR code prefills: a projekt/phase token when the
  # code points at one, a plain greeting for the portal-wide code.
  def self.prefilled_text_for(token)
    return I18n.t("adm.whatsapp.greeting") if token.blank?

    I18n.t("adm.whatsapp.prefilled_text", token: token)
  end

  def self.deep_link_url_for(token)
    deep_link_url(prefilled_text_for(token))
  end

  def self.qr_svg(text, module_size:)
    return if text.blank?

    RQRCode::QRCode.new(text).as_svg(
      module_size: module_size,
      standalone: true,
      use_path: true,
      viewbox: true
    )
  end

  def self.welcome_message_enabled?
    Setting["whatsapp.welcome_message_enabled"].present?
  end

  # Body of the list message the bot answers a first chat opening with. Admins
  # override it per portal; the translation is the fallback copy.
  def self.welcome_greeting
    Setting["whatsapp.welcome_greeting"].presence || I18n.t("whatsapp.bot.welcome_greeting")
  end

  def self.ice_breakers
    (1..MAX_ICE_BREAKERS).filter_map { |position| ice_breaker(position) }
  end

  def self.ice_breaker(position)
    Setting["whatsapp.ice_breaker_#{position}"].presence ||
      I18n.t("whatsapp.bot.ice_breakers.default_#{position}", default: nil).presence
  end

  # One command per line, "name|hint". The leading slash WhatsApp displays is
  # not part of the name, so it is dropped if an admin types it.
  def self.commands
    Setting["whatsapp.commands"].to_s.lines.filter_map { |line| command_from(line) }
  end

  def self.command_from(line)
    name, description = line.split(COMMAND_SEPARATOR, 2)
    name = name.to_s.strip.delete_prefix("/")

    return if name.blank?

    { command_name: name, command_description: description.to_s.strip }
  end
  private_class_method :command_from

  def self.broadcast_template_name
    Setting["whatsapp.broadcast_template"].presence
  end

  def self.broadcast_template_language
    Setting["whatsapp.broadcast_template_language"].presence || "de"
  end

  def self.transcription_model
    Setting["whatsapp.transcription_model"].presence || DEFAULT_TRANSCRIPTION_MODEL
  end

  def self.retention_days
    positive_setting("whatsapp.message_retention_days") || DEFAULT_RETENTION_DAYS
  end

  def self.max_voice_bytes
    megabytes = positive_setting("whatsapp.max_voice_megabytes") || DEFAULT_MAX_VOICE_MEGABYTES

    megabytes.megabytes
  end

  def self.positive_setting(key)
    value = Setting[key].to_i

    return if value <= 0

    value
  end
  private_class_method :positive_setting
end
