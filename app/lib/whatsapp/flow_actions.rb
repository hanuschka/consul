module Whatsapp::FlowActions
  # Every quick-reply pill the bot sends carries an id of one shape: what to do,
  # and optionally which record or setting to do it to. One shape means one
  # parser, so a pill tapped a week later is re-resolved rather than trusted.
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

  # Every id the bot may put on a button. It is a closed set for one reason: WhatsApp
  # returns the *id* to the webhook, so an id nothing knows is a tap that silently
  # does nothing — the citizen taps, sees no reply, and taps again.
  #
  # What the ids no longer carry is behaviour. Each one used to enter a scripted flow
  # of its own, which is why there are so many of them; now Inbound::TapDispatch turns
  # a tap into a note saying which button was pressed, and the assistant answers it
  # with whichever tool the words behind the label call for. That leaves exactly one
  # implementation of every write — the tool — which is what keeps the preconditions
  # on a publish or an unlink from having to exist in two places and drift apart.
  #
  # The recovery ids (retry, cancel, help) live in Whatsapp::Send instead, and they
  # are the ones that do still act on their own: cancelling has to work when no model
  # can be reached.
  ACTIONS = %i[
    main_menu
    participate
    participate_projekt
    submit_proposal
    idea_start
    discover
    discover_category
    discover_public
    view_projekt
    my_contributions
    notifications_open
    notifications_done
    notify_toggle
    unlink_start
    unlink_cancel
    unlink_confirm
    dismiss
    terms_accept
    terms_decline
    draft_publish
    draft_revise
    submit_final
    submit_anyway
    support
    support_prompt
    comment_prompt
    category
    sentiment
    image_upload
    image_generate
    image_skip
    location_share
    location_skip
    link_yes
    link_later
    link_retry
  ].freeze

  # The ids that point at one record or setting. Their parameter is what the
  # dispatcher re-resolves, and it is also what names the pill when the assistant
  # offers one without a label of its own — a projekt's own title beats a
  # paraphrase of it.
  PARAMETERISED_ACTIONS = %i[
    view_projekt participate_projekt idea_start category sentiment notify_toggle
    discover_category support
  ].freeze

  ID_PATTERN =
    /\A#{PREFIX}(?<action>[a-z_]+)(?:#{SEPARATOR}(?<param>[a-z0-9_]+))?\z/

  module_function

  def id_for(action:, param: nil)
    return "#{PREFIX}#{action}" if param.blank?

    "#{PREFIX}#{action}#{SEPARATOR}#{param}"
  end

  # Returns nil for anything that is not one of ours, including a pill from an
  # older deploy whose action no longer exists — the parked-flow pills and the
  # duplicate offer's "support instead" are both still sitting in chat histories.
  # The dispatcher answers those as a tap it cannot honour rather than dropping
  # them, because a tap that produces nothing reads as a bot that has died.
  def parse(reply_id)
    match = ID_PATTERN.match(reply_id.to_s)

    return if match.blank?

    action = match[:action].to_sym

    return if !ACTIONS.include?(action)

    { action: action, param: match[:param] }
  end

  def parameterised?(action)
    PARAMETERISED_ACTIONS.include?(action)
  end

  # Whether the id belongs to this vocabulary at all, either shape of it. Asked
  # before a label is built so an invented name is reported as one rather than as
  # a record that could not be found.
  def known?(action)
    ACTIONS.include?(action)
  end
end
