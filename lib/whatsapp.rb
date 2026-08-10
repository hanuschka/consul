module Whatsapp
  DEFAULT_TRANSCRIPTION_MODEL = "gpt-4o-mini-transcribe".freeze
  DEFAULT_RETENTION_DAYS = 90
  DEFAULT_MAX_VOICE_MEGABYTES = 16
  SERVICE_WINDOW = 24.hours
  WEBHOOK_EVENT_RETENTION = 7.days
  PUBLICATION_BROADCAST_DELAY = 20.minutes
  MAX_ICE_BREAKERS = 4
  COMMAND_SEPARATOR = "|".freeze

  # A WhatsApp list holds ten rows, and the bot has nowhere to paginate to, so
  # every query that fills one is capped here rather than per query object.
  # WhatsappApi::Resources::Messages enforces the same number at the protocol
  # edge, where it truncates and warns.
  MAX_LIST_ROWS = 10

  # A WhatsApp interactive message holds three reply buttons; anything longer
  # becomes a list instead. Declared beside the row cap for the same reason —
  # WhatsappApi::Resources::Messages enforces it again at the protocol edge.
  MAX_BUTTONS = 3

  # The models under this namespace keep their original tables, so the prefix is
  # declared once here rather than as a self.table_name on each of them.
  def self.table_name_prefix
    "whatsapp_"
  end

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

  # Last-resort credential for accounts where 360dialog stores the configured
  # security header but never sends it, leaving the caller nothing else to
  # present. Deliberately a separate value from webhook_secret: a URL reaches
  # access logs, and the API credential must not be what leaks there. Only
  # environments that set this key expose the route at all.
  def self.url_secret
    config[:url_secret]
  end

  def self.webhook_path
    helpers = Rails.application.routes.url_helpers

    return helpers.whatsapp_api_webhook_path if url_secret.blank?

    helpers.whatsapp_api_webhook_with_url_secret_path(url_secret)
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

  # Language for anyone the bot has no linked account for yet — the invitation
  # that precedes linking, and every reply to an unlinked number.
  def self.default_locale
    configured_locale = Setting["whatsapp.default_locale"].to_s

    return I18n.default_locale if !available_locale?(configured_locale)

    configured_locale
  end

  def self.available_locale?(locale)
    I18n.available_locales.map(&:to_s).include?(locale)
  end

  # The language to answer this number in: the linked citizen's own, falling
  # back to the portal default when they have none or it is not available.
  # Every job that replies asks the same question, so it is answered here.
  def self.locale_for(account)
    user_locale = account&.user&.locale.to_s

    return default_locale if !available_locale?(user_locale)

    user_locale
  end

  def self.welcome_message_enabled?
    Setting["whatsapp.welcome_message_enabled"].present?
  end

  # Body of the list message the bot answers a first chat opening with. Admins
  # override it per portal; the translation is the fallback copy.
  def self.welcome_greeting
    Setting["whatsapp.welcome_greeting"].presence || I18n.t("whatsapp.bot.welcome_greeting")
  end

  # The same admin-written greeting heads the central menu, which offers more
  # than submitting — only the fallback copy differs, because the default
  # greeting asks which projekt to contribute to and the menu does not.
  def self.menu_greeting
    Setting["whatsapp.welcome_greeting"].presence || I18n.t("whatsapp.archive.menu.body")
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
  #
  # Falls back to the translation the way ice breakers do. Unset, the number's
  # command menu is empty — and unlike the ice breakers, which vanish after the
  # first message, that menu is the one entry point still there weeks later.
  def self.commands
    configured = Setting["whatsapp.commands"].presence ||
                 I18n.t("whatsapp.bot.commands.default", default: nil).to_s

    configured.lines.filter_map { |line| command_from(line) }
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

  # The card variant is optional: without it every broadcast uses the plain
  # text template, and projekts with no image fall back to it either way.
  def self.broadcast_card_template_name
    Setting["whatsapp.broadcast_card_template"].presence
  end

  # Baked into the card template's URL button at approval time, with the projekt
  # id appended at send time — so it has to match `projekt_url` minus the id.
  def self.projekt_url_prefix
    "#{Rails.application.routes.url_helpers.projekts_url(**UrlOptions.default.to_h)}/"
  end

  # Whether a broadcast can be sent at all. Asked by the projekt details page
  # before it offers the button and by the action before it enqueues, so the two
  # cannot disagree about what "configured" means.
  def self.broadcast_available?
    enabled? && broadcast_template_name.present?
  end

  def self.broadcast_template_language
    Setting["whatsapp.broadcast_template_language"].presence || "de"
  end

  def self.auto_broadcast_new_projekts?
    Setting["whatsapp.auto_broadcast_new_projekts"].present?
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
