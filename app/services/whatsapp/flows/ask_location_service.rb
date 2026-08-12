class Whatsapp::Flows::AskLocationService < Whatsapp::Flows::BaseService
  # The map pin, offered after the picture and before publishing, on a phase
  # whose map feature is on. Always optional, exactly as it is on the web form:
  # the second pill submits without one.
  #
  # Two messages rather than one, because WhatsApp's location request carries no
  # reply buttons of its own — the choice has to be an ordinary button message,
  # and the native picker is what the first pill then sends. Three class methods
  # over three instance methods, the shape UnlinkService uses for its pair.
  def self.ask(conversation:)
    new(conversation: conversation).ask
  end

  def self.request(conversation:)
    new(conversation: conversation).request
  end

  def self.remind(conversation:)
    new(conversation: conversation).remind
  end

  def ask
    @conversation.update!(step: "awaiting_location")

    Whatsapp::Outbound.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.ask_location"),
      buttons: buttons
    )
  end

  # The picker itself. The step does not move: what this asks for is a location
  # message, and anything else at that step is answered by asking again.
  def request
    send_request("whatsapp.bot.proposal.location_request")
  end

  # The same picker with a line saying the last message was not a location. The
  # reminder is remembered on the conversation so the second miss publishes
  # instead of asking a third time — an optional field must not be able to hold
  # a finished submission.
  def remind
    @conversation.merge_context!(location_reminded: true)

    send_request("whatsapp.bot.proposal.location_retry")
  end

  private

    def send_request(body_key)
      Whatsapp::Outbound.location_request(
        account: account,
        body: Whatsapp.phrase(body_key)
      )
    end

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :location_share, label_key: "whatsapp.bot.buttons.location_share"
        ),
        Whatsapp::FlowActions.button(
          action: :location_skip, label_key: "whatsapp.bot.buttons.location_skip"
        )
      ]
    end
end
