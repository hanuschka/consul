class Ai::Tools::ProjektImports::AddImportPhase < Ai::Tools::ProjektImports::EditorTool
  description "Appends a new phase to the project import."

  params Ai::Tools::ProjektImports::PhaseParamSchema.without_index

  def execute(phase:)
    phase_index = editor.add_phase(phase.deep_stringify_keys)

    { status: "added", phase_index: phase_index }
  end
end
