module Whatsapp::NotificationTemplates
  # The pushes the catalog adds beyond the projekt announcement. All are sent
  # outside the 24-hour service window, so all have to be approved Meta templates
  # rather than freeform text.
  #
  # None of them names what it is about. This is the catalog's privacy-by-design
  # line and it is a constraint, not a style choice: the message body may not
  # carry the projekt's name, the proposal's title or a support count, because a
  # push arrives on a lock screen someone else can read. What it is about becomes
  # visible only after tapping through, whether that tap is a link in the body or
  # the template's own button.
  #
  # UTILITY rather than MARKETING: these follow from something the citizen
  # already engaged with. Submitting them as MARKETING gets them reclassified,
  # and repeated misclassification costs the number its quality rating.
  CATEGORY = "UTILITY".freeze

  # What shape each push is approved in, and so which submission it takes.
  #
  # `body` is the original form: one variable, and it is the URL. The two button
  # shapes carry no variable in the body at all — the push says what it is for and
  # the template's own button is the way in, which is what a vote needs: an
  # `action` button is a quick-reply whose tap comes back to us and is answered in
  # the chat, and a `link` button is a URL that opens the ballot.
  #
  # Both variants exist per voting kind rather than one template deciding at send
  # time, because a button's kind is approved with the template: a poll the chat
  # can carry gets the action template, and one it cannot gets the link.
  BODY_SHAPE = :body
  ACTION_SHAPE = :action
  LINK_SHAPE = :link

  SHAPES = {
    "deadline_approaching" => BODY_SHAPE,
    "deadline_passed" => BODY_SHAPE,
    "status_change" => BODY_SHAPE,
    "voting_started" => BODY_SHAPE,
    "voting_started_action" => ACTION_SHAPE,
    "voting_started_link" => LINK_SHAPE,
    "voting_ending" => BODY_SHAPE,
    "voting_ending_action" => ACTION_SHAPE,
    "voting_ending_link" => LINK_SHAPE
  }.freeze

  KINDS = SHAPES.keys.freeze

  # The voting kinds in the order the job tries them: the button templates first,
  # and the plain one as what still goes out before Meta has approved either.
  VOTING_VARIANTS_BY_KIND = {
    "voting_started" => %w[voting_started_action voting_started_link voting_started],
    "voting_ending" => %w[voting_ending_action voting_ending_link voting_ending]
  }.freeze

  SETTING_KEYS_BY_KIND = KINDS.index_with { |kind| "whatsapp.#{kind}_template" }.freeze

  EXAMPLE_VARIABLES = ["https://example.org/p/482"].freeze

  # The id a poll's ballot is reached by, for the URL button's approval example.
  EXAMPLE_BUTTON_VARIABLE = "482".freeze

  module_function

  def name_for(kind)
    Setting[SETTING_KEYS_BY_KIND.fetch(kind)].presence
  end

  def configured?(kind)
    name_for(kind).present?
  end

  # What a submission from the templates tab is called. Fixed rather than typed
  # so the tab can recognise the template it created among everything else on
  # the account, without a second setting per kind recording the name it chose.
  def submission_name(kind)
    "#{kind}_notification"
  end

  # The body a portal submits to Meta for approval. Read from the translations
  # so the wording the citizen sees is the catalog's, in the portal's own
  # language, rather than something retyped into an admin field.
  #
  # Rendered in the template's own language, not in the one the admin happens
  # to be browsing /adm in: Meta stores the language alongside the text, and a
  # German template carrying an English body is a template whose approval says
  # nothing about what citizens will read.
  def default_body(kind, language: nil)
    I18n.with_locale(body_locale(language)) do
      I18n.t(
        "whatsapp.bot.notifications.push.#{kind}",
        url: "{{1}}",
        portal_name: ::Whatsapp::PortalLinks.portal_name
      )
    end
  end

  def shape(kind)
    SHAPES[kind.to_s]
  end

  # The label the button is approved with, read in the template's own language
  # for the same reason the body is: Meta stores the two together.
  def button_label(kind, language: nil)
    label = shape(kind) == ACTION_SHAPE ? "vote_now" : "open_ballot"

    I18n.with_locale(body_locale(language)) do
      I18n.t("whatsapp.bot.notifications.push.buttons.#{label}")
    end
  end

  # The first variant of a voting push this portal can actually send, or nil while
  # none of the three is armed. The action template is preferred only where the
  # poll is one the chat can carry to the end — everywhere else its button would
  # start a ballot the bot then has to abandon.
  def voting_variant(kind, votable:)
    variants = VOTING_VARIANTS_BY_KIND.fetch(kind.to_s)
    variants = variants.drop(1) if !votable

    variants.find { |variant| configured?(variant) }
  end

  def create(kind:, language: nil)
    return if !::Whatsapp.configured?

    language = language.presence || ::Whatsapp.broadcast_template_language
    templates = WhatsappApi::Client.new.templates

    case shape(kind)
    when ACTION_SHAPE
      templates.create_reply_button(
        name: submission_name(kind),
        language: language,
        body: default_body(kind, language: language),
        button_label: button_label(kind, language: language),
        category: CATEGORY
      )
    when LINK_SHAPE
      templates.create_link_button(
        name: submission_name(kind),
        language: language,
        body: default_body(kind, language: language),
        button_label: button_label(kind, language: language),
        button_url_prefix: ::Whatsapp.poll_url_prefix,
        example_button_variable: EXAMPLE_BUTTON_VARIABLE,
        category: CATEGORY
      )
    else
      templates.create(
        name: submission_name(kind),
        language: language,
        body: default_body(kind, language: language),
        example_variables: EXAMPLE_VARIABLES,
        category: CATEGORY
      )
    end
  end

  # One row per kind for the templates tab: the body that would be submitted,
  # what Meta reports about it, and the name the jobs actually read.
  #
  # Matched on language as well as name because every push goes out in
  # broadcast_template_language — the same name approved in another language is
  # not a template this portal can send.
  def states(listed_templates)
    language = ::Whatsapp.broadcast_template_language

    KINDS.map { |kind| state(kind, listed_templates, language) }
  end

  def state(kind, listed_templates, language)
    name = submission_name(kind)

    listed = listed_templates.find do |template|
      template[:name] == name && template[:language] == language
    end

    {
      kind: kind,
      name: name,
      language: language,
      body: default_body(kind, language: language),
      button: shape(kind) == BODY_SHAPE ? nil : button_label(kind, language: language),
      configured_name: name_for(kind),
      submitted: listed.present?,
      status: listed&.fetch(:status),
      approved: listed.present? && listed[:approved]
    }
  end

  # A template language is a Meta code ("de", "de_DE"); a locale here is a Rails
  # one ("de", "de-DE"). Anything the portal has no translations for falls back
  # to the base language and then to the admin's own locale, so a body is never
  # submitted with the key printed in it.
  def body_locale(language)
    locale = language.to_s.tr("_", "-").presence&.to_sym

    return I18n.locale if locale.blank?
    return locale if I18n.available_locales.include?(locale)

    base_locale = locale.to_s.split("-").first.to_sym

    return base_locale if I18n.available_locales.include?(base_locale)

    I18n.locale
  end

  private_class_method :state, :body_locale
end
