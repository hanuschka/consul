class Ai::Tools::ProjektImports::ReplaceImportPhase < RubyLLM::Tool
  description "Replaces one phase of the project import with a new version. Read the " \
              "phase with read_import_data first and send it back complete, with only " \
              "the parts the user asked to change modified. Anything you omit from the " \
              "phase object is lost, so always include its poll questions, events, " \
              "milestones and other resources."

  params Ai::Tools::ProjektImports::PhaseParamSchema.with_index

  def initialize(editor:)
    @editor = editor
  end

  def name
    "replace_import_phase"
  end

  def execute(phase_index:, phase:)
    @editor.replace_phase(phase_index, phase.deep_stringify_keys)

    { status: "replaced", phase_index: phase_index }
  rescue ProjektImports::AiResultEditor::IndexError => e
    { error: e.message }
  end
end
