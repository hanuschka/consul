module Whatsapp::FlowActions
  # Every quick-reply pill the flow catalog sends carries an id of one shape:
  # what to do, and optionally which record or setting to do it to. One shape
  # means one parser, so a pill tapped a week later is re-resolved rather than
  # trusted.
  #
  #   whatsapp_flow_link_yes                   no parameter
  #   whatsapp_flow_support-4821               proposal 4821
  #   whatsapp_flow_notify_toggle-new_supports the notification type
  #
  # The separator is a dash rather than an underscore because the action itself
  # contains underscores; a single delimiter that cannot occur inside the action
  # is what keeps the pattern unambiguous.
  PREFIX = "whatsapp_flow_".freeze
  SEPARATOR = "-".freeze

  ONBOARDING_ACTIONS = %i[
    link_yes
    link_later
    link_retry
    link_switch
    unlink_confirm
    unlink_cancel
  ].freeze

  DISCOVERY_ACTIONS = %i[discover discover_category discover_public dismiss view_projekt].freeze

  PROPOSAL_ACTIONS = %i[
    submit_proposal
    idea_start
    terms_accept
    terms_decline
    category
    sentiment
    draft_publish
    draft_revise
    submit_anyway
    image_upload
    image_generate
    image_skip
    location_share
    location_skip
    submit_final
    resume
    restart
    continue_flow
    start_over
    resume_parked
  ].freeze

  # `support_instead` is supporting from the duplicate offer, and it is its own
  # action rather than a `support` tapped at the right moment: it also ends the
  # submission it interrupted, and that consequence has to travel on the pill.
  # Inferred from the step instead, an ordinary support pill — which the
  # assistant can offer at any moment, including that one — would silently
  # discard a half-written submission.
  ENGAGEMENT_ACTIONS = %i[support support_instead my_contributions].freeze

  NOTIFICATION_ACTIONS = %i[notify_toggle notifications_done].freeze

  # The rows of the main menu and the button every dead end now ends in. They
  # are their own group because none of them does anything on its own: each
  # only puts the citizen where typing the same words would have.
  #
  # support_prompt and comment_prompt are no longer menu rows — the menu offers
  # `participate` instead, and the project chosen there is what decides which
  # of the three appears. They stay registered because the assistant still
  # reaches them from free text, and because a pill sent before this change is
  # still sitting in someone's chat history.
  MENU_ACTIONS = %i[
    main_menu
    participate
    participate_projekt
    support_prompt
    comment_prompt
    notifications_open
    unlink_start
  ].freeze

  ACTIONS = (
    ONBOARDING_ACTIONS + DISCOVERY_ACTIONS + PROPOSAL_ACTIONS +
      ENGAGEMENT_ACTIONS + NOTIFICATION_ACTIONS + MENU_ACTIONS
  ).freeze

  ID_PATTERN =
    /\A#{PREFIX}(?<action>[a-z_]+)(?:#{SEPARATOR}(?<param>[a-z0-9_]+))?\z/

  module_function

  def id_for(action:, param: nil)
    return "#{PREFIX}#{action}" if param.blank?

    "#{PREFIX}#{action}#{SEPARATOR}#{param}"
  end

  # Returns nil for anything that is not one of ours, including a pill from an
  # older deploy whose action no longer exists.
  def parse(reply_id)
    match = ID_PATTERN.match(reply_id.to_s)

    return if match.blank?

    action = match[:action].to_sym

    return if !ACTIONS.include?(action)

    { action: action, param: match[:param] }
  end

  def button(action:, label_key:, param: nil)
    { id: id_for(action: action, param: param), title: I18n.t(label_key) }
  end

  # One selectable row, for the menus that are lists rather than button sets.
  # A list row carries a description a button has no room for, which is what
  # lets the menu name four capabilities without a sentence above each.
  def row(action:, title_key:, description_key:, param: nil)
    {
      id: id_for(action: action, param: param),
      title: I18n.t(title_key),
      description: I18n.t(description_key)
    }
  end

  # The pair every "this cannot go in as it stands" message offers. Two of them
  # now end this way — a failed phase criterion, and a draft the portal's own
  # validations rejected — and they ask the citizen the same question, so they
  # must not offer two different ways to answer it.
  #
  # Unlike the sets around it, one of the two is a recovery pill: it is handled
  # globally rather than by the step, which is what lets the same word typed
  # instead of tapped mean the same thing.
  def revise_decision_buttons
    [
      button(action: :draft_revise, label_key: "whatsapp.bot.buttons.draft_revise"),
      ::Whatsapp::Send.recovery_button(:cancel)
    ]
  end

  # The two pills that leave a step for AskLocationService, which either asks
  # for a pin or publishes on the spot depending on whether the phase collects
  # one. Labelled "Beitrag einreichen" and "Ohne Bild einreichen" they promised
  # submission and were followed by another question — the one thing a citizen
  # cannot trust a button about afterwards, because the next tap is the
  # irreversible one.
  #
  # Both labels are fixed text; which of the pair is sent is a property of the
  # phase, decided once here rather than per message. Two steps offer these
  # pills, and a label that means "this submits" in one and "this continues" in
  # the other is how the pair drifts.
  def submit_final_button(conversation)
    button(
      action: :submit_final,
      label_key: continuation_label_key(
        conversation,
        continue_key: "whatsapp.bot.buttons.submit_continue",
        submit_key: "whatsapp.bot.buttons.submit_final"
      )
    )
  end

  def image_skip_button(conversation)
    button(
      action: :image_skip,
      label_key: continuation_label_key(
        conversation,
        continue_key: "whatsapp.bot.buttons.image_skip_continue",
        submit_key: "whatsapp.bot.buttons.image_skip"
      )
    )
  end

  # Both keys are spelled out at the call sites rather than derived from the
  # action, so every label stays greppable — the property AskDraftChoiceService
  # ::CHOICES protects for the same reason. What is shared is the one condition,
  # so a third continuation pill cannot introduce a third copy of it.
  def continuation_label_key(conversation, continue_key:, submit_key:)
    return continue_key if conversation.location_question_available?

    submit_key
  end

  # The pair every "this one needs an account" message offers. Declining is the
  # menu rather than a "later": the citizen asked for something specific and
  # the answer to a refused account is the rest of what they can still do, not
  # the end of the conversation.
  def link_request_buttons
    [
      button(action: :link_yes, label_key: "whatsapp.bot.buttons.link_yes"),
      button(action: :main_menu, label_key: "whatsapp.bot.buttons.back_to_menu")
    ]
  end

  # The pair the consent question offers, shaped after link_request_buttons: one
  # pill that resolves it and one that ends the attempt in the menu. Declining is
  # its own action rather than a bare :main_menu, because it has a sentence to
  # say first — that nothing can be submitted without the acceptance — and a
  # citizen dropped into the menu with no explanation reads it as the tap having
  # failed.
  def terms_consent_buttons
    [
      button(action: :terms_accept, label_key: "whatsapp.bot.buttons.terms_accept"),
      button(action: :terms_decline, label_key: "whatsapp.bot.buttons.back_to_menu")
    ]
  end
end
