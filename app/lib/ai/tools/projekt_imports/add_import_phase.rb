class Ai::Tools::ProjektImports::AddImportPhase < RubyLLM::Tool
  description "Appends a new phase to the project import."

  params Ai::Tools::ProjektImports::PhaseParamSchema.without_index

  def initialize(editor:)
    @editor = editor
  end

  def name
    "add_import_phase"
  end

  def execute(phase:)
    phase_index = @editor.add_phase(phase.deep_stringify_keys)

    { status: "added", phase_index: phase_index }
  end
end
