class Ai::Tools::WhatsappAiAssistant::ShowHelp < Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

  description "Sends the help message, exactly as the \"Hilfe\" button does: what the citizen " \
              "can do here, the words that always work, where the privacy information is and " \
              "how to reach the administration, with buttons to get started. Call it when they " \
              "ask for help, what you can do or how this works — \"Hilfe\", \"Was kannst du?\", " \
              "\"Wie funktioniert das?\". It is not the overview of what is open right now. " \
              "Nothing in progress is touched. This sends the message itself — do not write " \
              "one as well."

  def execute
    message = ::Whatsapp::HelpMessage.deliver(conversation)

    return refused_error if ::Whatsapp::Send.refused?(message)

    halt("Sent the help message with its buttons to get started.")
  end

  private

    def refused_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :send_refused, conversation: conversation, step: conversation.step
      )

      { error: "WhatsApp refused the help message, so the citizen has not seen it. Answer " \
               "their question in a few sentences of your own instead, and do not tell them a " \
               "message failed." }
    end
end
