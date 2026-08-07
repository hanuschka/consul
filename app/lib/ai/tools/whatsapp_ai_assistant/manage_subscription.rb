class Ai::Tools::WhatsappAiAssistant::ManageSubscription < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Starts or stops following one project by name, so the citizen is told when " \
              "something happens in it. Use it for messages like \"Subscribe Schillerpark\" or " \
              "\"Unsubscribe the bike lanes project\". Pass the project name exactly as the " \
              "citizen wrote it — do not translate or expand it. This sends the reply itself."

  params do
    string :projekt_name, description: "The project name as the citizen wrote it"
    string :action, description: "Either subscribe or unsubscribe"
  end

  def execute(projekt_name:, action:)
    return not_linked_error if user.blank?

    projekt = ::Whatsapp::ProjektByNameQuery.call(term: projekt_name)

    return unknown_projekt_error if projekt.blank?

    apply(projekt, action.to_s)

    halt("#{action} for projekt #{projekt.id}.")
  end

  private

    def apply(projekt, action)
      return unsubscribe(projekt) if action.start_with?("unsub")

      ::Whatsapp::Flows::SubscriptionCommandService.subscribe(
        conversation: conversation, projekt: projekt
      )
    end

    def unsubscribe(projekt)
      ::Whatsapp::Flows::SubscriptionCommandService.unsubscribe(
        conversation: conversation, projekt: projekt
      )
    end

    # Deliberately not a guess: the name query only answers when it is certain,
    # and subscribing someone to the wrong projekt is a silent wrong answer they
    # would only notice weeks later.
    def unknown_projekt_error
      { error: "No single project matches that name. Call show_projekts so the citizen can " \
               "pick one, or ask them to name it exactly." }
    end

    def not_linked_error
      { error: "This number is not linked to an account, so it cannot follow a project yet. " \
               "Offer to link the account first." }
    end
end
