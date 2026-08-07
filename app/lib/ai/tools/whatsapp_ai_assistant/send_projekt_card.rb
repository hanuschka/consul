class Ai::Tools::WhatsappAiAssistant::SendProjektCard < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen one projekt as a card — its title, subtitle, picture and link — " \
              "in a message of its own. Call this whenever you point the citizen at one specific " \
              "projekt, instead of writing its address into your reply. Takes the " \
              "projekt_phase_id the read tools return. The card carries the link, so do not " \
              "repeat it in the reply you write afterwards."

  params do
    integer :projekt_phase_id, description: "Id of the open participation phase to show"
  end

  def execute(projekt_phase_id:)
    projekt_phase = eligible_phase(projekt_phase_id)

    return unknown_phase_error if projekt_phase.blank?

    ::Whatsapp::Flows::SendProjektCardService.call(
      conversation: conversation, projekt: projekt_phase.projekt
    )

    { sent: true, projekt: projekt_title(projekt_phase.projekt) }
  end
end
