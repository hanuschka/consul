class Ai::Tools::WhatsappAiAssistant::ListProjektContributions <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen what other people have already submitted to one project — its " \
              "published proposals and budget investments, newest first, each with the link to " \
              "open it. Use it for questions like what have people suggested or what is already " \
              "in there. These are everyone's contributions, not this citizen's own. This sends " \
              "the message itself — do not write one as well."

  params do
    string :projekt_name, description: "The project name as the citizen wrote it"
  end

  def execute(projekt_name:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    ::Whatsapp::Flows::ProjektContributionsService.call(
      conversation: conversation, projekt: projekt
    )

    halt("Sent what has been submitted to this project.")
  end
end
