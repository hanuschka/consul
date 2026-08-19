class Ai::Tools::WhatsappAiAssistant::RequestLocation < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Opens WhatsApp's own location picker so the citizen can drop a pin. The pin it " \
              "produces is the only way to get an exact position, so this is the tool for a " \
              "phase that collects one — draft_status says whether this phase does. Always " \
              "optional: never hold a finished draft for a pin, and never ask twice. When they " \
              "have already named the place in words there is nothing to ask, and when they say " \
              "they do not know it, publish without one. This sends the picker itself — do not " \
              "write a message as well, and note that the picker carries no buttons, so anything " \
              "else you want to offer has to be a separate message."

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

    halt("Opened the location picker.")
  end

  private

    def not_collected_error
      { error: "This phase does not collect a location, so there is nowhere to put a pin. Go on " \
               "to publishing instead." }
    end

    def blank_body_error
      { error: "The picker needs a sentence above it saying what it is for." }
    end
end
