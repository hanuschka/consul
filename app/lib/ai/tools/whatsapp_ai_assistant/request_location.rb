class Ai::Tools::WhatsappAiAssistant::RequestLocation < Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

  description "Opens WhatsApp's own location picker so the citizen can drop a pin. The pin it " \
              "produces is the only way to get an exact position, so this is the tool for a " \
              "phase that collects one — draft_status says whether this phase does. Always " \
              "optional: never hold a finished draft for a pin, and never ask twice — a second " \
              "call for the same draft is refused. Where a place read from their words is " \
              "waiting for their answer, ask about that place instead; where they named one " \
              "that was not found on the map, this is how it gets there. Publishing refuses " \
              "until the place has been asked about once, not until a pin arrives, so when " \
              "they say they do not know it, go on without one. This sends the picker itself " \
              "— do not " \
              "write a message as well. The picker can carry no buttons of its own, so a second " \
              "short message follows it with the way to go on without a pin and the note that a " \
              "pin can only be set in the app on the phone — WhatsApp Web and Desktop cannot " \
              "show the picker at all. That message is sent for you; do not write it, or the " \
              "note, yourself."

  parameters do
    string :body,
      description: "The sentence above the picker, in the citizen's language, saying the pin is " \
                   "optional."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_LOCATION
  end

  def execute(body:)
    refusal = refuse_before_preview

    return refusal if refusal.present?
    return no_draft_error if draft_resource.blank?
    return not_collected_error if !conversation.location_question_available?
    return already_requested_error if conversation.location_requested?
    return blank_body_error if body.to_s.strip.blank?

    picker = ::Whatsapp::Send.location_request(account: account, body: body.strip)

    return picker_failed_error if !delivered?(picker)

    offer_to_continue_without

    conversation.record_location_requested!

    halt("Opened the location picker, with a second message offering to go on without a pin.")
  end

  private

    # The picker is the one message WhatsApp lets us send with nothing tappable
    # beside it, and it used to be the end of the turn: a citizen with no pin to give
    # — which the phase explicitly allows — had to work out that typing something was
    # their way out. So the offer follows in a message of its own.
    #
    # Its own send rather than a line appended above the picker, because the picker's
    # body is the assistant's question and this is the answer to it. The one pill on
    # it is location_skip: the citizen is in the middle of being asked something, so
    # nothing is offered beside it that leaves the question.
    #
    # The sentence and the label go through one translation call, not two and not one
    # of each: a body in the citizen's language over a button in the portal's is the
    # split every other send here exists to avoid.
    def offer_to_continue_without
      written_label = ::Whatsapp.copy("whatsapp.bot.buttons.location_skip")
      body, label = ::Whatsapp::AiAssistant::BotCopyService.call(
        account: account,
        lines: [::Whatsapp.copy("whatsapp.bot.proposal.location_optional"), written_label]
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

    # Publishing counts the place as asked once this is recorded, so a picker
    # the citizen never received must not count — the same rule the picture
    # notices follow (Whatsapp::ImageQuestion).
    def delivered?(message)
      message.present? && !::Whatsapp::Send.refused?(message)
    end

    def picker_failed_error
      { error: "The location picker could not be sent, so the place has not been asked about. " \
               "Ask in words whether they want to add one; where they would rather go without, " \
               "pass location_declined when you show them the contribution again." }
    end

    def not_collected_error
      { error: "This phase does not collect a location, so there is nowhere to put a pin. Go on " \
               "to publishing instead." }
    end

    def already_requested_error
      { error: "The pin for this draft has already been asked for once, so nothing was sent. " \
               "Go on without one — a pin they share later is still attached." }
    end

    def blank_body_error
      { error: "The picker needs a sentence above it saying what it is for." }
    end
end
