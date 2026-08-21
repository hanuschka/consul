class Ai::Tools::WhatsappAiAssistant::RequestLocation < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Opens WhatsApp's own location picker so the citizen can drop a pin. The pin it " \
              "produces is the only way to get an exact position, so this is the tool for a " \
              "phase that collects one — draft_status says whether this phase does. Always " \
              "optional: never hold a finished draft for a pin, and never ask twice. When they " \
              "have already named the place in words there is nothing to ask, and when they say " \
              "they do not know it, publish without one. This sends the picker itself — do not " \
              "write a message as well. The picker can carry no buttons of its own, so a second " \
              "short message follows it with the way to go on without a pin; that is sent for " \
              "you and you do not write it either."

  params do
    string :body,
      description: "The sentence above the picker, in the citizen's language, saying the pin is " \
                   "optional."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_LOCATION
  end

  def execute(body:)
    return no_draft_error if draft_resource.blank?
    return not_collected_error if !conversation.location_question_available?
    return blank_body_error if body.to_s.strip.blank?

    ::Whatsapp::Send.location_request(account: account, body: body.strip)

    offer_to_continue_without

    halt("Opened the location picker, with a second message offering to go on without a pin.")
  end

  private

    # The picker is the one message WhatsApp lets us send with nothing tappable
    # beside it, and it used to be the end of the turn: a citizen with no pin to give
    # — which the phase explicitly allows — had to work out that typing something was
    # their way out. So the offer follows in a message of its own.
    #
    # Its own send rather than a line appended above the picker, because the picker's
    # body is the assistant's question and this is the answer to it. Send puts the
    # main menu beside location_skip, so the second message carries two.
    #
    # The sentence and the label go through one translation call, not two and not one
    # of each: a body in the citizen's language over a button in the portal's is the
    # split every other send here exists to avoid.
    def offer_to_continue_without
      written_label = I18n.t("whatsapp.bot.buttons.location_skip")
      body, label = ::Whatsapp::AiAssistant::BotCopyService.call(
        account: account,
        lines: [I18n.t("whatsapp.bot.proposal.location_optional"), written_label]
      )

      ::Whatsapp::Send.buttons(
        account: account,
        body: body,
        buttons: [
          {
            id: ::Whatsapp::FlowActions.id_for(action: :location_skip),
            title: ::Whatsapp::AssistantActions.fitting_label(
              translated: label, original: written_label
            )
          }
        ]
      )
    end

    def not_collected_error
      { error: "This phase does not collect a location, so there is nowhere to put a pin. Go on " \
               "to publishing instead." }
    end

    def blank_body_error
      { error: "The picker needs a sentence above it saying what it is for." }
    end
end
