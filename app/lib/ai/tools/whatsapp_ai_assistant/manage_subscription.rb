class Ai::Tools::WhatsappAiAssistant::ManageSubscription < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Starts or stops following one project by name, so the citizen is told when " \
              "something happens in it. Use it for messages like \"Subscribe Schillerpark\" or " \
              "\"Unsubscribe the bike lanes project\". Pass the project name exactly as the " \
              "citizen wrote it — do not translate or expand it. Pass action as exactly " \
              "subscribe or unsubscribe; never guess the direction. This sends the reply itself."

  SUBSCRIBE = "subscribe".freeze
  UNSUBSCRIBE = "unsubscribe".freeze
  DIRECTIONS = [SUBSCRIBE, UNSUBSCRIBE].freeze

  # Constrained in the schema rather than repaired in Ruby. This was a prefix
  # test (`start_with?("unsub")`), and every other wording a model produces for
  # stopping — "unfollow", "stop", "remove" — fell through to subscribing: the
  # opposite of what the citizen asked for, and not something they can tell from
  # the confirmation they get back. A synonym map would only move that guess,
  # leaving the next unlisted word to be a deploy; an enum means the provider
  # cannot emit a third value at all.
  params(
    type: "object",
    properties: {
      projekt_name: {
        type: "string",
        description: "The project name as the citizen wrote it"
      },
      action: {
        type: "string",
        enum: DIRECTIONS,
        description: "Whether to start or stop following the project"
      }
    },
    required: %w[projekt_name action],
    additionalProperties: false
  )

  def execute(projekt_name:, action:)
    return not_linked_error("follow a project yet") if user.blank?

    direction = action.to_s.strip.downcase

    return unclear_direction_error if !DIRECTIONS.include?(direction)

    projekt = projekt_for(projekt_name, direction)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    apply(projekt, direction)

    halt("#{direction} for projekt #{projekt.id}.")
  end

  private

    # Stopping is resolved against what the citizen actually follows; starting
    # keeps the default set, because following a projekt only makes sense while
    # it is running.
    #
    # The difference is load-bearing: that default is index_order_underway,
    # which excludes a projekt that has finished. Asked to stop hearing about
    # one, the bot used to answer that no such projekt existed — and the
    # messages carried on. The follow set carries no such filter, so the
    # finished projekt is found here.
    #
    # Deliberately no wider second pass. The follow set is already complete and
    # uncapped, so a superset could only ever resolve a projekt the citizen
    # does not follow — nothing to unfollow, at the price of scanning the whole
    # portal on every typo. A name that resolves to nothing is a question for
    # the citizen instead, which is the one answer that is never wrong here.
    def projekt_for(projekt_name, direction)
      return ::Whatsapp::ProjektByNameQuery.call(term: projekt_name) if direction == SUBSCRIBE

      ::Whatsapp::ProjektByNameQuery.call(
        term: projekt_name, candidates: ::Whatsapp::FollowedProjektsQuery.uncapped(user: user)
      )
    end

    def apply(projekt, direction)
      return ::Whatsapp::Flows::SubscriptionCommandService.subscribe(
        conversation: conversation, projekt: projekt
      ) if direction == SUBSCRIBE

      ::Whatsapp::Flows::SubscriptionCommandService.unsubscribe(
        conversation: conversation, projekt: projekt
      )
    end

    # The enum should make this unreachable; it stands as the floor for a
    # provider that does not enforce schemas. Never guesses a direction —
    # following someone who asked to be left alone cannot be told apart from
    # having succeeded.
    def unclear_direction_error
      { error: "action must be exactly \"subscribe\" or \"unsubscribe\". Ask the citizen which " \
               "of the two they meant rather than calling this again with a guess." }
    end
end
