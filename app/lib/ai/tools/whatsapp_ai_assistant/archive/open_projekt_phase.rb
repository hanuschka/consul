class Ai::Tools::WhatsappAiAssistant::OpenProjektPhase < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Opens one participation phase's own menu: taking part in it, what others " \
              "contributed there, its results, and its page. Use it when the citizen asks about " \
              "one particular phase rather than the projekt as a whole. Take the " \
              "projekt_phase_id from list_open_phases. To put them straight into submitting, " \
              "call start_phase_flow instead. This sends the message itself — do not write one " \
              "as well."

  params do
    integer :projekt_phase_id, description: "Id of the participation phase to open"
  end

  def execute(projekt_phase_id:)
    handled = ::Whatsapp::MenuActionService.call(
      conversation: conversation,
      scope: :phase,
      record_id: projekt_phase_id.to_i,
      action: :menu
    )

    return { error: "No participation phase with that id is visible right now." } if !handled

    halt("Opened the menu for projekt phase #{projekt_phase_id}.")
  end
end
