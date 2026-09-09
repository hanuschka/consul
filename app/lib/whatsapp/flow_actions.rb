module Whatsapp::FlowActions
  # Every quick-reply pill the bot sends carries an id of one shape: what to do,
  # and optionally which record or setting to do it to. One shape means one
  # parser, so a pill tapped a week later is re-resolved rather than trusted.
  #
  #   whatsapp_flow_link_yes                   no parameter
  #   whatsapp_flow_support-4821               proposal 4821
  #   whatsapp_flow_poll_weight-4821_3          option 4821, three of the budget
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
  #
  # `main_menu` is the exception on both counts. It acts on its own — the inbound
  # layer clears the active phase on it, because a way back to the beginning that
  # needs a model to be reachable is not one — and yet it keeps its id here rather
  # than moving to the recovery namespace beside `help`, which now behaves the same.
  # Moving it would change the id, and every start-over pill the bot has ever sent is
  # still sitting in a chat history and still tappable.
  ACTIONS = %i[
    main_menu
    participate
    participate_projekt
    submit_proposal
    idea_start
    phase_open
    phase_contributions
    poll_answer
    poll_weight
    poll_done
    poll_skip
    discover
    discover_category
    discover_public
    view_projekt
    my_contributions
    view_contribution
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
    support_toggle
    comment_prompt
    comment_post
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
  # Three, which is every slot the message has, and all three are the question's own
  # now that nothing is appended to it. Generation was offered in words before
  # and only once the citizen said they had no photo of their own, so a citizen who
  # did not already know it existed read a message naming two ways out and took one
  # of them. The middle answer is the whole reason the third slot is spent.
  IMAGE_ANSWERS = %i[image_upload image_generate image_skip].freeze

  # The ids that point at one record or setting. Their parameter is what the
  # dispatcher re-resolves, and it is also what names the pill when the assistant
  # offers one without a label of its own — a projekt's own title beats a
  # paraphrase of it.
  PARAMETERISED_ACTIONS = %i[
    view_projekt participate_projekt idea_start phase_open phase_contributions poll_answer
    poll_weight poll_done poll_skip
    category sentiment notify_toggle discover_category support support_toggle show_more
    view_contribution
  ].freeze

  # Ids the bot composes itself and the assistant may never write. Distinct from the
  # retired ones, which are ids nothing offers because something else took them over:
  # these are current, and the reason they are withheld is the label rather than the
  # action — a model writing a label here is a vote filed under wording nobody was
  # shown, or a way out of a question that is not being asked.
  # `poll_answer` carries one option of a ballot, and its words have to be that
  # option's own as the poll records them. `poll_weight` carries an option and a
  # number together — how much of a weighted question's budget that option is to
  # take — and its label is the number, which is nothing a model has anything to add
  # to. `poll_done` and `poll_skip` are the two ways out of a question the bot is in
  # the middle of asking — one says the citizen has picked everything they want from
  # a multiple-choice question, the other declines a free-text or a map one — and
  # all of them are meaningless outside a ballot in flight. A model offering one of
  # them mid-conversation is a pill that answers a question nobody was asked.
  BOT_ONLY_ACTIONS = %i[poll_answer poll_weight poll_done poll_skip].freeze

  # The two pills that answer a tap on this side rather than by asking the assistant,
  # and the reason they are separated from the rest: the projekt card offers a phase's
  # own action, and the action has to begin on the tap — a note saying which button was
  # pressed is a model being asked to choose a tool, which is the selection step the
  # card exists to remove. Their parameter is a phase id, re-resolved on arrival like
  # every other.
  #
  # `phase_open` is for the phase types the bot has no submission flow for — voting, a
  # form, a point of interest. What it starts is the phase on the portal, because that
  # is where the action lives; the pill is still worth offering, since naming the
  # action is what tells the citizen the phase is open at all.
  DIRECT_PHASE_ACTIONS = %i[phase_open phase_contributions].freeze

  # Answered on this side too, and for a reason of its own: a row naming one
  # contribution has to answer with that contribution, and a note handed to the
  # assistant is a model choosing which of several tools opens it. Its parameter
  # names a kind and an id together, which is why it is not one of the two above —
  # Whatsapp::ContributionPill is what reads it.
  DIRECT_CONTRIBUTION_ACTION = :view_contribution

  # The ids another action has taken over. They stay in ACTIONS because every pill
  # the bot has ever sent is still sitting in a chat history and still tappable, so
  # a tap on one is still answered; what they lose is their place in the vocabulary
  # the assistant is offered, which is where the duplication did the damage.
  #
  # `participate_projekt` and `view_projekt` both meant "this is the projekt I
  # want" and were answered the same way — that projekt's card. Two ids for one
  # intent is what let a guard written against one of them fire on the other, so
  # only `view_projekt` is offered now.
  #
  # `support` and `support_prompt` were the two halves of an offer and a
  # confirmation: the first asked, the second acted, and a support needed both. It
  # takes one tap now, and which way that tap goes depends on the vote as it stands
  # when it arrives — so the pill is `support_toggle` and neither of the old pair can
  # be offered again. A tap on one still registers, because it still means the one
  # thing it ever meant.
  RETIRED_ACTIONS = %i[participate_projekt support support_prompt].freeze

  # The pills that put a projekt or a participation phase in front of the citizen,
  # as against the ones that act on a draft, a comment or a setting. Two things read
  # it, and both are asking the same question about a message that has already been
  # composed: which rows carry a name that needs no line under it, and whether this
  # was a message on which the bot may say a question can simply be typed.
  #
  # Answered from the pill ids rather than from the body, because the body is the
  # model's own sentence in whatever language the citizen wrote in — there is nothing
  # in it Ruby can match on.
  PROJEKT_CHOICE_ACTIONS = %i[view_projekt idea_start discover_category].freeze

  # `show_more`'s parameter names a list rather than a record: which of the capped
  # lists the citizen wants the rest of. Every list the bot can send is capped at
  # ten rows and none of them could say what was left out, so this is the one
  # parameter that is a scope name — which is also why it is an allowlist rather
  # than something read off the id. A scope name arriving from a chat message is
  # the shape that reaches a query nobody meant to expose.
  MORE_SCOPES = %w[
    open_projekts
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

  # Whether any of these pill ids offered a projekt or a phase. Takes the whole set
  # because the question is about the message rather than about one button: a reply
  # whose second pill is the projekt still presented one.
  def projekt_choice?(reply_ids)
    Array(reply_ids).any? do |reply_id|
      PROJEKT_CHOICE_ACTIONS.include?(parse(reply_id)&.dig(:action))
    end
  end

  def parameterised?(action)
    PARAMETERISED_ACTIONS.include?(action)
  end

  # Answered on this side rather than by the assistant. Asked where a tap is
  # dispatched, before the note describing it would be composed.
  def direct_phase?(action)
    DIRECT_PHASE_ACTIONS.include?(action)
  end

  # Whether the id belongs to this vocabulary at all, either shape of it. Asked
  # before a label is built so an invented name is reported as one rather than as
  # a record that could not be found.
  def known?(action)
    ACTIONS.include?(action)
  end

  # Still honoured on a tap, never offered again. Asked where a pill is composed
  # rather than where one is dispatched, which is the whole point of the set.
  def retired?(action)
    RETIRED_ACTIONS.include?(action)
  end

  # Everything the assistant may not compose, for whichever of the two reasons. One
  # answer because every caller asking has the same question — may the model put this
  # on a button — and none of them cares which list said no.
  def unofferable
    RETIRED_ACTIONS + BOT_ONLY_ACTIONS
  end

  def unofferable?(action)
    unofferable.include?(action)
  end
end
