class Ai::Tools::ProjektImports::RemoveImportPhase < Ai::Tools::ProjektImports::EditorTool
  description "Proposes removing one phase from the project import. The phase is NOT " \
              "removed by this call: the administrator sees the proposal under your " \
              "message and applies or discards it with a button. Only call this when " \
              "the user explicitly asked for the phase to be deleted, and call it once " \
              "per phase."

  params(
    type: "object",
    properties: Ai::Tools::ProjektImports::PhaseParamSchema::INDEX_PROPERTY,
    required: %w[phase_index],
    additionalProperties: false
  )

  def execute(phase_index:)
    proposal = editor.propose_remove_phase(phase_index)

    {
      status: "proposed",
      proposal_id: proposal["proposal_id"],
      phase_type: proposal.dig("details", "type"),
      note: "Not removed yet. Tell the user in one sentence to confirm the " \
            "removal with the Apply button shown under this message."
    }
  rescue ::ProjektImports::AiResultEditor::IndexError => e
    { error: e.message }
  end
end
