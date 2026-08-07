class Ai::Tools::WhatsappAiAssistant::RefuseOutOfScope < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Politely declines a question that is not about this participation portal — " \
              "opening hours, the weather, city services, anything the portal does not cover — " \
              "and points at the portal's help page. Use it instead of answering from your own " \
              "knowledge. This sends the message itself."

  def execute
    ::Whatsapp::Flows::OutOfScopeService.call(conversation: conversation)

    halt("Declined an out-of-scope question.")
  end
end
