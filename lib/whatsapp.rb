module Whatsapp
  DEFAULT_TRANSCRIPTION_MODEL = "gpt-4o-mini-transcribe".freeze
  DEFAULT_RETENTION_DAYS = 90
  DEFAULT_MAX_VOICE_MEGABYTES = 16
  SERVICE_WINDOW = 24.hours

  def self.config
    Rails.application.secrets.whatsapp || {}
  end

  def self.api_key
    config[:api_key]
  end

  def self.webhook_secret
    config[:webhook_secret]
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
