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

  DISCOVERY_ACTIONS = %i[discover discover_public dismiss view_projekt].freeze

  PROPOSAL_ACTIONS = %i[
    submit_proposal
    idea_start
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
  ].freeze

  # `support_instead` is supporting from the duplicate offer, and it is its own
  # action rather than a `support` tapped at the right moment: it also ends the
  # submission it interrupted, and that consequence has to travel on the pill.
  # Inferred from the step instead, an ordinary support pill — which the
  # assistant can offer at any moment, including that one — would silently
  # discard a half-written submission.
  ENGAGEMENT_ACTIONS = %i[support support_instead my_contributions].freeze

  NOTIFICATION_ACTIONS = %i[notify_toggle notifications_done].freeze

  # The rows of the help list and the button every dead end now ends in. They
  # are their own group because none of them does anything on its own: each
  # only puts the citizen where typing the same words would have.
  MENU_ACTIONS = %i[
    main_menu
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

  # The three things a citizen can start from nothing. Defined once because
  # three separate messages now offer them — the greeting, the cancellation and
  # the confirmation after publishing — and a set that drifts between them
  # reads as three different menus.
  def main_menu_buttons
    [
      button(action: :submit_proposal, label_key: "whatsapp.bot.buttons.submit_proposal"),
      button(action: :discover, label_key: "whatsapp.bot.buttons.show_projekts"),
      button(action: :my_contributions, label_key: "whatsapp.bot.buttons.my_contributions")
    ]
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

  # The pair every "shall we link your account" message offers, whether it is
  # the first contact or a return visit. One definition so the two cannot drift
  # into offering different words for the same choice.
  def link_decision_buttons
    [
      button(action: :link_yes, label_key: "whatsapp.bot.buttons.link_yes"),
      button(action: :link_later, label_key: "whatsapp.bot.buttons.link_later")
    ]
  end
end
