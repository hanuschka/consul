class Ai::Tools::WhatsappAiAssistant::ShowProjekts < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen the portal's participation projects, grouped by whether " \
              "participation is open, the project is still running, it is still to come or it " \
              "is finished, each with its link. Use it when they ask what projects there are, " \
              "what is running, or to see the projects. This sends the message itself — do not " \
              "write one as well."

  def execute
    ::Whatsapp::Flows::BrowseProjektsService.call(conversation: conversation)

    halt("Sent the grouped list of the portal's projects.")
  end
end
