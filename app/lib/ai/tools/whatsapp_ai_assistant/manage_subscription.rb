class Ai::Tools::WhatsappAiAssistant::ManageSubscription < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Starts or stops following one project by name, so the citizen is told when " \
              "something happens in it. Use it for messages like \"Subscribe Schillerpark\" or " \
              "\"Unsubscribe the bike lanes project\". Pass the project name exactly as the " \
              "citizen wrote it — do not translate or expand it. Pass action as exactly " \
              "subscribe or unsubscribe; never guess the direction. This sends the reply itself."

  SUBSCRIBE = :subscribe
  UNSUBSCRIBE = :unsubscribe

  # Decided against a list rather than by a prefix test. Read as
  # `start_with?("unsub")`, every other wording the model produces for stopping
  # — "unfollow", "stop", "remove" — fell through to subscribing, which is the
  # opposite of what the citizen asked for and is not something they can tell
  # from the confirmation they get back. A word that is not on this list is a
  # question for the citizen, never a guess.
  DIRECTIONS = {
    "subscribe" => SUBSCRIBE,
    "follow" => SUBSCRIBE,
    "unsubscribe" => UNSUBSCRIBE,
    "unfollow" => UNSUBSCRIBE,
    "stop" => UNSUBSCRIBE
  }.freeze

  params do
    string :projekt_name, description: "The project name as the citizen wrote it"
    string :action, description: "Exactly subscribe or unsubscribe"
  end

  def execute(projekt_name:, action:)
    return not_linked_error("follow a project yet") if user.blank?

    direction = DIRECTIONS[action.to_s.strip.downcase]

    return unclear_direction_error if direction.blank?

    projekt = projekt_for(projekt_name, direction)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    apply(projekt, direction)

    halt("#{direction} for projekt #{projekt.id}.")
  end

  private

    # Stopping is resolved against what the citizen actually follows first, and
    # only then against the whole readable portal. Starting keeps the default
    # set, because following a projekt only makes sense while it is running.
    #
    # The difference is load-bearing: that default is index_order_underway,
    # which excludes a projekt that has finished. Asked to stop hearing about
    # one, the bot used to answer that no such projekt existed — and the
    # messages carried on.
    def projekt_for(projekt_name, direction)
      return ::Whatsapp::ProjektByNameQuery.call(term: projekt_name) if direction == SUBSCRIBE

      ::Whatsapp::ProjektByNameQuery.call(term: projekt_name, candidates: followed_projekts) ||
        ::Whatsapp::ProjektByNameQuery.readable(term: projekt_name)
    end

    def followed_projekts
      ::Whatsapp::FollowedProjektsQuery.uncapped(user: user)
    end

    def apply(projekt, direction)
      return subscribe(projekt) if direction == SUBSCRIBE

      unsubscribe(projekt)
    end

    def subscribe(projekt)
      ::Whatsapp::Flows::SubscriptionCommandService.subscribe(
        conversation: conversation, projekt: projekt
      )
    end

    def unsubscribe(projekt)
      ::Whatsapp::Flows::SubscriptionCommandService.unsubscribe(
        conversation: conversation, projekt: projekt
      )
    end

    def unclear_direction_error
      { error: "action must be exactly \"subscribe\" or \"unsubscribe\". Ask the citizen which " \
               "of the two they meant — do not call this again with a guess, because following " \
               "someone who asked to be left alone cannot be told apart from succeeding." }
    end
end
