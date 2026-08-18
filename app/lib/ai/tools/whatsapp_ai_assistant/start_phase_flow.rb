class Ai::Tools::WhatsappAiAssistant::StartPhaseFlow < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Puts the citizen into the guided submission flow for one open participation " \
              "phase, which then asks them for their idea. Use it once they have named which " \
              "phase they want to contribute to. This sends the message itself — do not write " \
              "one as well. You take no further part in the submission after this."

  params do
    integer :projekt_phase_id, description: "Id of the open participation phase to submit to"
  end

  def execute(projekt_phase_id:)
    projekt_phase = eligible_phase(projekt_phase_id)

    return unknown_phase_error if projekt_phase.blank?

    # Whatever was already open is set aside rather than replaced: entering a
    # flow rewrites the whole context, so a citizen who changes projekt
    # mid-submission used to lose the draft they had.
    park_open_flow!

    # Refuses on its own and resets the flow when the citizen may not take
    # part, so the permission rule stays in one place.
    ::Whatsapp::Flows::StartPhaseFlowService.call(
      conversation: conversation, projekt_phase: projekt_phase
    )

    halt("Started the submission flow for projekt phase #{projekt_phase.id}.")
  end
end
