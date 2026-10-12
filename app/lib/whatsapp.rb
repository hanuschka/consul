module Whatsapp
  DEFAULT_TRANSCRIPTION_MODEL = "gpt-4o-mini-transcribe".freeze
  DEFAULT_RETENTION_DAYS = 90
  DEFAULT_MAX_VOICE_MEGABYTES = 16
  SERVICE_WINDOW = 24.hours
  WEBHOOK_EVENT_RETENTION = 7.days
  PUBLICATION_BROADCAST_DELAY = 20.minutes

  # ── Where the bot's jobs sit in the shared queue ────────────────────────
  # Everything in this app runs on one Delayed Job queue at the default
  # priority of 0, so an inbound reply used to wait behind whatever was already
  # in it: an evaluation being generated, a PDF being rendered, or a projekt
  # broadcast, which is one job per fifty numbers and a synchronous send per
  # number inside each.
  #
  # A citizen is watching a typing bubble that expires in 25 seconds, so
  # answering one outranks everything the app does; a broadcast nobody is
  # waiting on yields to everything, the replies to its own arrivals included.
  # Lower is sooner.
  REPLY_PRIORITY = -10
  BULK_PRIORITY = 20

  # A WhatsApp list holds ten rows. WhatsappApi::Resources::Messages enforces the
  # same number at the protocol edge, where it truncates and warns.
  MAX_LIST_ROWS = 10

  # What a list can actually offer, which is now every row it holds: a list no
  # longer carries the way to start over, so the row that used to be reserved for it
  # goes back to the options. This is the number every query that fills a list is
  # capped at and the size of a Whatsapp::ListWindow page — a query answering with
  # more than a list can carry hands the model rows nobody sees, and a window
  # counting more as shown pages straight past them.
  MAX_OFFERED_LIST_ROWS = MAX_LIST_ROWS

  # The line under a list row's title. WhatsappApi::Resources::Messages cuts it
  # to this at the protocol edge, mid-word, so a caller that fits a name into it
  # has to count to the same number.
  MAX_ROW_DESCRIPTION_LENGTH = 72

  # A WhatsApp interactive message holds three reply buttons; anything longer
  # becomes a list instead. Declared beside the row cap for the same reason —
  # WhatsappApi::Resources::Messages enforces it again at the protocol edge.
  #
  # All three belong to the caller. Only the sends that end the conversation add the
  # start-over pill, and there it takes a slot like any other answer: a dead end that
  # already names three ways on is not one.
  MAX_BUTTONS = 3

  # Whether this many rows arrive as buttons printing their own wording rather than
  # behind WhatsApp's picker, which two places have to agree on: the sender numbers
  # the options and prints them in the message only where the picker would hide
  # them, and the gate that decides whether a ballot can be voted in a chat at all
  # only asks whether two options can be told apart on a button where a button is
  # what they arrive on.
  def self.buttons?(rows_count)
    rows_count <= MAX_BUTTONS
  end

  # What one message will hold, which the preview has to answer to rather than
  # truncate: a plain text message takes far more than a picture's caption or an
  # interactive message's body, so a block that fits none of the three is split
  # across several rather than cut. Declared beside the other protocol caps.
  MAX_TEXT_BODY_LENGTH = 4096
  MAX_CAPTION_LENGTH = 1024
  MAX_INTERACTIVE_BODY_LENGTH = 1024

  # WhatsApp fetches a header or card picture itself, from us, while the send is
  # in flight, and rejects the whole message over anything it cannot render. Any
  # caller that puts one on a message answers to these two numbers, so they are
  # declared once here rather than per card.
  HEADER_IMAGE_CONTENT_TYPES = ["image/jpeg", "image/png"].freeze
  HEADER_IMAGE_MAX_BYTES = 5.megabytes

  # Every description the bot quotes is rich text written in the portal's
  # editor, and WhatsApp renders no markup at all — so each one is flattened
  # the same way and cut to whatever the message it lands in has room for.
  # Declared once because three messages now do it at three different lengths,
  # and how portal HTML becomes chat text is one decision, not three.
  #
  # The block boundaries become the breaks before the tags go, because stripping
  # them first is not a lost blank line but a lost word boundary: strip_tags
  # turns "<p>fehlen Bügel.</p><p>Zweiter Absatz</p>" into
  # "fehlen Bügel.Zweiter Absatz", and a citizen reading that in the block they
  # are asked to confirm is reading something the portal does not hold.
  PARAGRAPH_END = %r{</(?:p|div|li|h[1-6]|blockquote|tr)>}i
  LINE_BREAK = %r{<br\s*/?>}i

  def self.plain_text(html, length:)
    broken = html.to_s.gsub(PARAGRAPH_END, "\n\n").gsub(LINE_BREAK, "\n")

    ActionController::Base.helpers
      .strip_tags(broken)
      .gsub(/[^\S\n]+/, " ")
      .gsub(/ *\n */, "\n")
      .gsub(/\n{3,}/, "\n\n")
      .strip
      .truncate(length)
  end

  # Nil rather than a placeholder when the picture is missing or unusable:
  # every caller has a shape it falls back to, and a broken image is worse than
  # none.
  def self.header_image_url(attachment)
    return if !usable_header_image?(attachment)

    Rails.application.routes.url_helpers.rails_blob_url(attachment, **::UrlOptions.default.to_h)
  end

  # Whether WhatsApp will render this attachment at all. Asked on its own
  # because a picture can reach a message either as a URL it fetches or as
  # media uploaded to it, and both routes answer to the same two numbers.
  def self.usable_header_image?(attachment)
    return false if attachment.blank? || !attachment.attached?
    return false if !HEADER_IMAGE_CONTENT_TYPES.include?(attachment.blob.content_type)

    attachment.blob.byte_size <= HEADER_IMAGE_MAX_BYTES
  end

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

  def self.switched_on?
    Setting["feature.whatsapp_bot"].present?
  end

  def self.enabled?
    switched_on? && configured?
  end

  # Raised by a job that finds the bot switched on but its own process without
  # credentials. Secrets are read once per process, so a Delayed Job worker
  # started before they were added keeps running without them after Puma has
  # been restarted onto them — and the jobs it ran used to return in silence,
  # dropping every reply. Raised instead, so ApplicationJob's retry_on holds
  # the job until the worker is restarted (Whatsapp::WorkerHeartbeat).
  class MissingCredentialsError < StandardError; end

  def self.ensure_credentials_loaded!
    return if !switched_on?
    return if configured?

    message = "[Whatsapp] the bot is switched on but this process has no " \
              "#{missing_required_credential_keys.join(", ")}: restart it to load them"

    raise MissingCredentialsError, message
  end

  # Tells two processes' credentials apart without either revealing them: a
  # digest of the whole block, so a rotated key counts as a change as much as an
  # added one.
  def self.credentials_fingerprint
    Digest::SHA256.hexdigest(config.to_h.sort.to_s).first(16)
  end

  # Everything that keeps the bot from answering citizens, in the order an admin
  # has to clear it: without credentials or the switch it does not run at all,
  # a worker still on older credentials cannot send what it is handed, a
  # signature the deliveries fail stops every message at the door, and without
  # an AI provider every typed or spoken message is answered with the "can't
  # answer right now" line (ProcessMessageService#answer).
  def self.blocking_reasons
    ai_feature_enabled = ::Ai::Settings.feature_enabled?

    [
      (:missing_credentials if !configured?),
      (:switched_off if !switched_on?),
      (:worker_outdated if ::Whatsapp::WorkerHeartbeat.outdated?),
      ::Whatsapp::SignatureRefusal.unresolved_reason,
      (:ai_disabled if !ai_feature_enabled),
      (:ai_provider_unavailable if ai_feature_enabled && !::Ai::Settings.ai_available?)
    ].compact
  end

  # The secret each way of authenticating a webhook delivery needs. A way whose
  # secret is missing is unavailable, never passed
  # (WhatsappApi::BaseController#authenticated?).
  WEBHOOK_AUTHENTICATION_SECRET_KEYS = {
    header_secret: :webhook_secret,
    signature: :webhook_signature_secret,
    url_secret: :url_secret
  }.freeze

  WEBHOOK_AUTHENTICATION_SETUP = "Set whatsapp.webhook_secret and re-register the webhook, so " \
                                 "360dialog sends it back as a header; add the 360dialog " \
                                 "Hub platform secret as whatsapp.webhook_signature_secret " \
                                 "to require signed deliveries on top.".freeze

  def self.webhook_authentication_methods
    WEBHOOK_AUTHENTICATION_SECRET_KEYS.select { |_method, key| config[key].present? }.keys
  end

  # Mirrors WhatsappApi::BaseController#authenticated?: a configured signature is
  # required on top of either shared secret, never instead of it.
  def self.webhook_authentication_summary
    shared_secrets = (webhook_authentication_methods - [:signature]).join(" or ")

    return shared_secrets if webhook_signature_secret.blank?

    "signature plus #{shared_secrets}"
  end

  # Said once at boot and read off the secrets alone: the feature setting lives
  # in the database, which a boot for assets:precompile does not have. Silent
  # where the instance holds no WhatsApp configuration at all. A configured
  # instance always holds the header secret, so the one case with no way to
  # authenticate a delivery is the unconfigured one, where the webhook refuses
  # everything.
  def self.report_webhook_authentication
    return if config.blank?

    if !configured?
      message = "[Whatsapp] missing #{missing_required_credential_keys.join(", ")}: the bot is " \
                "off and every webhook delivery is refused. #{WEBHOOK_AUTHENTICATION_SETUP}"

      warn(message)
      Rails.logger.error(message)

      return
    end

    Rails.logger.info(
      "[Whatsapp] webhook deliveries are authenticated by #{webhook_authentication_summary}"
    )
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

  # The language of the portal's own copy, and the one every fixed line falls
  # back to before the assistant has written anything to a number.
  def self.default_locale
    configured_locale = Setting["whatsapp.default_locale"].to_s

    return I18n.default_locale if !available_locale?(configured_locale)

    configured_locale
  end

  def self.available_locale?(locale)
    I18n.available_locales.map(&:to_s).include?(locale)
  end

  # The language the conversation is held in: the one the assistant last wrote
  # in, which is a model's reading of the whole exchange rather than of a single
  # word. A typed "START" or "Abbrechen" is answered by the keyword gate before
  # any model is asked, so it cannot move this. Nil until the assistant has
  # written something.
  def self.conversation_language(account)
    return if account.blank?

    ::Whatsapp::Message.latest_reply_language(account: account)
  end

  # The locale the fixed copy is rendered in: the conversation's language where
  # the portal has copy in it, and the portal's own otherwise. A language with no
  # copy is translated from the portal's, which is the one that carries the
  # du/Sie choice. Every job that replies asks the same question, so it is
  # answered here.
  def self.locale_for(account)
    language = conversation_language(account).to_s

    return default_locale if !available_locale?(language)

    language
  end

  # How the bot addresses the citizen. German splits this in two and every
  # portal has an answer already — a city writes "Sie", a youth participation
  # project writes "du" — so it is a setting rather than a translation. Both the
  # generated prose and the fixed copy follow it.
  ADDRESS_FORMS = %w[sie du].freeze
  DEFAULT_ADDRESS_FORM = "sie".freeze

  def self.address_form
    configured = Setting["whatsapp.address_form"].to_s.downcase

    return DEFAULT_ADDRESS_FORM if !ADDRESS_FORMS.include?(configured)

    configured
  end

  # Where the bot's fixed copy lives, and where the informal wording of it lives.
  # The locale files are written formally, and the second tree holds German only and
  # only the lines that read differently — so it is an override rather than a
  # translation, and anything missing from it falls back to the formal line: every
  # line in English, where there is nothing to choose between, and every German line
  # that is the same either way.
  BOT_SCOPE = "whatsapp.bot".freeze
  INFORMAL_BOT_SCOPE = "whatsapp.bot_du".freeze

  # The bot's fixed copy in the address form the portal chose. Every read of a
  # whatsapp.bot key goes through here rather than through I18n directly, because
  # nothing about a key says whether its wording differs between the two forms — and
  # a portal that duzt everywhere except in one consent notice is the split this
  # setting exists to prevent. A key outside the bot's own scope is passed through
  # untouched, so a caller need not know which it is holding.
  #
  # The formal key goes in front of whatever default the caller passed rather than
  # replacing it: the formally written line is a better answer than a caller's
  # stand-in, and a caller's default overwriting it would have been silent.
  #
  # Two lookups rather than one with the formal key as a default, because a
  # caller's `default: nil` has to stay nil. Folded into a default list it no
  # longer does: I18n answers "Translation missing" once every entry of a list
  # comes back empty, which is a label on a button where nil drops the button.
  #
  # The informal lookup never falls back to another locale. The tree is German
  # only and every locale here falls back to German, so an English turn asking for
  # it was answered with the German "du" line rather than its own formal one.
  def self.copy(key, **options)
    return I18n.t(key, **options) if address_form == DEFAULT_ADDRESS_FORM

    prefix = "#{BOT_SCOPE}."

    return I18n.t(key, **options) if !key.to_s.start_with?(prefix)

    informal = "#{INFORMAL_BOT_SCOPE}.#{key.to_s.delete_prefix(prefix)}"

    I18n.t(informal, **options, default: nil, fallback: false) || I18n.t(key, **options)
  end

  # The sentence every prompt that writes German for a citizen carries. Written
  # once because two of them do — the assistant's own replies and the reworded
  # routine lines — and a portal answering formally in one and informally in
  # the other is the failure this setting exists to prevent.
  def self.address_form_instruction
    return 'informally, with "du" (or the equivalent in other languages)' if address_form == "du"

    'formally, with "Sie" (or the equivalent in other languages)'
  end

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

  # Baked into the voting notification's URL button at approval time, with the
  # poll id appended at send time — so it has to match `poll_url` minus the id.
  def self.poll_url_prefix
    "#{Rails.application.routes.url_helpers.polls_url(**UrlOptions.default.to_h)}/"
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

  # Where the administration takes enquiries that are not about participation.
  # Every field is optional; the bot names whichever ones are filled in.
  def self.administration_contact_phone
    Setting["whatsapp.administration_contact_phone"].to_s.squish.presence
  end

  def self.administration_contact_email
    Setting["whatsapp.administration_contact_email"].to_s.strip.presence
  end

  def self.administration_contact_url
    Setting["whatsapp.administration_contact_url"].to_s.strip.presence
  end

  def self.administration_contact_entered?
    [
      administration_contact_phone, administration_contact_email, administration_contact_url
    ].any?
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
