class Ai::Tools::ProjektImports::RemoveImportPhase < Ai::Tools::ProjektImports::EditorTool
  description "Removes one phase from the project import. Only call this when the user " \
              "explicitly asked for the phase to be deleted."

  params(
    type: "object",
    properties: Ai::Tools::ProjektImports::PhaseParamSchema::INDEX_PROPERTY,
    required: %w[phase_index],
    additionalProperties: false
  )

  def execute(phase_index:)
    removed = editor.remove_phase(phase_index)

    { status: "removed", phase_type: removed["type"] }
  rescue ::ProjektImports::AiResultEditor::IndexError => e
    { error: e.message }
  end
end
