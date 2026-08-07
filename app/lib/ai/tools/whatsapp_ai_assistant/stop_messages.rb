class Ai::Tools::WhatsappAiAssistant::StopMessages < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Stops all WhatsApp messages to this citizen. Call it the moment they ask not to " \
              "be written to any more, however they phrase it — no more messages, leave me " \
              "alone, unsubscribe, take me off the list. Never argue, never ask them to confirm " \
              "and never tell them to write STOPP instead: honouring this is not optional. " \
              "This sends the confirmation itself — do not write one as well."

  def execute
    ::Whatsapp::Steps::SetMessageDeliveryService.disable(conversation: conversation)

    halt("Turned off all messages for this citizen.")
  end
end
