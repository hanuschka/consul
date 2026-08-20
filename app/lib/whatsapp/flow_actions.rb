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
  # of its own, which is why there are so many of them; now the inbound side turns a
  # tap into one line saying which button was pressed, and the assistant answers it
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
    show_more
  ].freeze

  # The ways to answer the picture question, in the order they are offered.
  # Declared here rather than in the tool that sends them because the order is what
  # pairs each id with its label, and a set built twice is a set that can pair them
  # differently.
  #
  # Two, not three: Whatsapp::Send keeps the last of a message's three slots for the
  # main menu. Sending a photo and going on without one are the two answers the
  # citizen must be able to give by tapping — a photo is always optional, and that
  # is the pill that makes it so. Having one generated is offered in words instead,
  # which the generate tool's own description already asks for when they say they
  # have no picture of their own.
  IMAGE_ANSWERS = %i[image_upload image_skip].freeze

  # The ids that point at one record or setting. Their parameter is what the
  # dispatcher re-resolves, and it is also what names the pill when the assistant
  # offers one without a label of its own — a projekt's own title beats a
  # paraphrase of it.
  PARAMETERISED_ACTIONS = %i[
    view_projekt participate_projekt idea_start category sentiment notify_toggle
    discover_category support show_more
  ].freeze

  # `show_more`'s parameter names a list rather than a record: which of the capped
  # lists the citizen wants the rest of. Every list the bot can send is capped at
  # ten rows and none of them could say what was left out, so this is the one
  # parameter that is a scope name — which is also why it is an allowlist rather
  # than something read off the id. A scope name arriving from a chat message is
  # the shape that reaches a query nobody meant to expose.
  MORE_SCOPES = %w[
    eligible_phases
    my_contributions
    results
    polls
    followed_projekts
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
