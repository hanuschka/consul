class Ai::Tools::WhatsappAiAssistant::ShowProjekts < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen the list of participation projects they can contribute to " \
              "right now, each tappable to start a proposal. Use it when they ask what is " \
              "running, what they can take part in, or to see the projects. This sends the " \
              "message itself — do not write one as well."

  def execute
    ::Whatsapp::Flows::DiscoveryService.linked(conversation: conversation)

    halt("Sent the list of open participation projects.")
  end
end
