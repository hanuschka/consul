module Whatsapp::NotificationTemplates
  # The three pushes the catalog adds beyond the projekt announcement. All are
  # sent outside the 24-hour service window, so all have to be approved Meta
  # templates rather than freeform text.
  #
  # One variable each, and that variable is a URL. This is the catalog's
  # privacy-by-design line and it is a constraint, not a style choice: the
  # message body may not carry the projekt's name, the proposal's title or a
  # support count, because a push arrives on a lock screen someone else can
  # read. What it is about becomes visible only after tapping through.
  #
  # UTILITY rather than MARKETING: these follow from something the citizen
  # already engaged with. Submitting them as MARKETING gets them reclassified,
  # and repeated misclassification costs the number its quality rating.
  CATEGORY = "UTILITY".freeze

  KINDS = %w[deadline_approaching deadline_passed status_change].freeze

  SETTING_KEYS_BY_KIND = KINDS.index_with { |kind| "whatsapp.#{kind}_template" }.freeze

  EXAMPLE_VARIABLES = ["https://example.org/p/482"].freeze

  module_function

  def name_for(kind)
    Setting[SETTING_KEYS_BY_KIND.fetch(kind)].presence
  end

  def configured?(kind)
    name_for(kind).present?
  end

  # The body a portal submits to Meta for approval. Read from the translations
  # so the wording the citizen sees is the catalog's, in the portal's own
  # language, rather than something retyped into an admin field.
  def default_body(kind)
    I18n.t(
      "whatsapp.bot.notifications.push.#{kind}",
      url: "{{1}}",
      portal_name: ::Whatsapp::PortalLinks.portal_name
    )
  end

  def create(kind:, language: nil)
    return if !::Whatsapp.configured?

    WhatsappApi::Client.new.templates.create(
      name: "#{kind}_notification",
      language: language.presence || ::Whatsapp.broadcast_template_language,
      body: default_body(kind),
      example_variables: EXAMPLE_VARIABLES,
      category: CATEGORY
    )
  end
end
