class Ai::Tools::WhatsappAiAssistant::Archive::SendProjektLink < ::Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen a tappable button opening the web page of the projekt behind an " \
              "open participation phase. Use it when they want to read more, see other people's " \
              "contributions, or do something the chat cannot do. This sends the message itself " \
              "— do not write one as well."

  params do
    integer :projekt_phase_id, description: "Id of an open participation phase"
    string :body, description: "One or two sentences introducing the link, in the citizen's language"
  end

  def execute(projekt_phase_id:, body:)
    projekt_phase = eligible_phase(projekt_phase_id)

    return unknown_phase_error if projekt_phase.blank?

    ::Whatsapp::Flows::SendLinkButtonService.call(
      conversation: conversation,
      body: body,
      url: projekt_url(projekt_phase.projekt)
    )

    halt("Sent the citizen a link button to projekt phase #{projekt_phase.id}.")
  end
end
