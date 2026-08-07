class Ai::Tools::WhatsappAiAssistant::ClarifyIntent < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Asks whether the citizen means a new proposal or a comment on an existing one. " \
              "Use it only when the message is about participating but genuinely could be " \
              "either — not as a general 'I did not understand'. This sends the message itself."

  def execute
    ::Whatsapp::Flows::ClarifyIntentService.call(conversation: conversation)

    halt("Asked the citizen to clarify proposal or comment.")
  end
end
