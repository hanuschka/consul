module Whatsapp::AssistantActions
  # Which of the catalog's pills the assistant may put under a reply of its own,
  # and what each one is labelled. Before this it had three — help, cancel,
  # retry — so every reply that wanted to lead somewhere had to describe the way
  # there in prose and hope the citizen typed it.
  #
  # The model chooses among these; it never authors one. WhatsApp rejects an
  # unknown button id as a failed send rather than a validation error, and a
  # pill's effect is still decided by Inbound::FlowActionDispatch when it is
  # tapped — account gating, record re-resolution and all. So the freedom here
  # is freedom to offer, never freedom to act.
  #
  # Left out: the three pills that cannot be taken back from a chat, plus the
  # one that severs the account. Publishing a draft, submitting it, registering
  # support and confirming an unlink are all reached through the flow that first
  # says what is about to happen — never as a button the assistant thought to
  # add.
  FORBIDDEN_ACTIONS = %i[draft_publish submit_final support support_instead unlink_confirm].freeze

  # WhatsApp truncates a button title past this, mid-word, with no ellipsis.
  MAX_LABEL_LENGTH = 20

  # The pills whose label is the same sentence every time, so it lives in the
  # locale file. A label key is shared wherever two actions read as the same
  # offer to the citizen: `dismiss` and `unlink_cancel` are both "no thanks",
  # and both `discover_public` and the digest pill say what they list.
  STATIC_LABEL_KEYS = {
    main_menu: "main_menu",
    help: "help",
    cancel: "cancel",
    retry: "retry",
    submit_proposal: "submit_proposal",
    idea_start: "idea_start",
    participate: "participate",
    discover: "show_projekts",
    discover_public: "show_current_projekts",
    dismiss: "no_thanks",
    my_contributions: "my_contributions",
    notifications_open: "notifications_open",
    notifications_done: "done",
    unlink_start: "unlink_start",
    unlink_cancel: "no_thanks",
    terms_accept: "terms_accept",
    terms_decline: "terms_decline",
    draft_revise: "draft_revise",
    submit_anyway: "submit_anyway",
    image_upload: "image_upload",
    image_generate: "image_generate",
    image_skip: "image_skip",
    location_share: "location_share",
    location_skip: "location_skip",
    resume: "resume",
    resume_parked: "resume",
    restart: "restart",
    continue_flow: "continue_flow",
    start_over: "start_over",
    link_yes: "link_yes",
    link_later: "link_later",
    link_retry: "login_again",
    link_switch: "link_switch",
    support_prompt: "support_prompt",
    comment_prompt: "comment_prompt"
  }.freeze

  # The pills that point at one record or setting. Their label is the thing
  # itself — a projekt's title, a category's name — so it is read from the
  # record, which is also what validates the parameter: a projekt that does not
  # exist, a label the phase does not offer and a notification type nobody has
  # heard of all come back without a name, and an unnamed pill is not offered.
  PARAMETERISED_ACTIONS = %i[
    view_projekt participate_projekt category sentiment notify_toggle discover_category
  ].freeze

  module_function

  # Every id the assistant may name, for the instructions it is given. The
  # parameterised ones are listed by shape rather than enumerated: the records
  # behind them arrive from whichever tool the model just called, and enumerating
  # a portal's projekts here would be the whole portal in every prompt.
  def offerable_action_names
    STATIC_LABEL_KEYS.keys.map(&:to_s)
  end

  def parameterised_action_names
    PARAMETERISED_ACTIONS.map(&:to_s)
  end

  # One tappable button from the "action" or "action-param" the model named, or
  # nil when that is not something it may offer. Nil rather than an exception on
  # purpose: one unusable pill in a set of three should cost that pill, not the
  # reply.
  def button(spec:, conversation:)
    action, param = parse(spec)

    return if action.blank?
    return if FORBIDDEN_ACTIONS.include?(action)

    label = label_for(action: action, param: param, conversation: conversation)

    return if label.blank?

    { id: id_for(action: action, param: param), title: label.truncate(MAX_LABEL_LENGTH) }
  end

  def parse(spec)
    action, param = spec.to_s.strip.delete_prefix(::Whatsapp::FlowActions::PREFIX)
      .split(::Whatsapp::FlowActions::SEPARATOR, 2)

    return [nil, nil] if action.blank?

    [action.to_sym, param.presence]
  end

  # A recovery pill keeps its own id namespace — the inbound side reads those
  # before the catalog's, and that ordering is what lets "Abbrechen" beside two
  # catalog pills be understood without a step of its own.
  def id_for(action:, param:)
    recovery_id = ::Whatsapp::Send::RECOVERY_ACTION_IDS[action]

    return recovery_id if recovery_id.present?

    ::Whatsapp::FlowActions.id_for(action: action, param: param)
  end

  def label_for(action:, param:, conversation:)
    return parameterised_label(action: action, param: param, conversation: conversation) if
      PARAMETERISED_ACTIONS.include?(action)

    label_key = STATIC_LABEL_KEYS[action]

    return if label_key.blank?
    return if param.present?

    I18n.t("whatsapp.bot.buttons.#{label_key}")
  end

  def parameterised_label(action:, param:, conversation:)
    return if param.blank?

    case action
    when :view_projekt, :participate_projekt then projekt_label(param)
    when :category
      taxonomy_label(::Whatsapp::DraftTaxonomy.category(conversation.projekt_phase), param)
    when :sentiment
      taxonomy_label(::Whatsapp::DraftTaxonomy.sentiment(conversation.projekt_phase), param)
    when :notify_toggle then notification_label(param)
    when :discover_category then browse_category_label(param)
    end
  end

  # The title as the portal writes it, through the same reader the cards and
  # lists use, so a pill and the message above it name the projekt identically.
  def projekt_label(param)
    projekt = ::Projekt.find_by(id: param.to_i)

    return if projekt.blank?

    ::Whatsapp::ProjektLink.title(projekt)
  end

  # Only the options the phase on the table actually offers. This is the check
  # that keeps a category pill from carrying a label id belonging to another
  # phase — the tap would be refused by the policy anyway, one message later
  # and with nothing said about why.
  def taxonomy_label(policy, param)
    policy.options.find { |option| option.id.to_s == param.to_s }&.name
  end

  def notification_label(param)
    type = ::Whatsapp::Account::NOTIFICATION_TYPES.find { |known| known.to_s == param.to_s }

    return if type.blank?

    I18n.t("whatsapp.bot.notifications.types.#{type}.short")
  end

  def browse_category_label(param)
    group = ::Whatsapp::CategorizedProjektsQuery.category(key: param)

    return if group.blank?

    I18n.t("custom.projekts.filters.#{param}")
  end
end
