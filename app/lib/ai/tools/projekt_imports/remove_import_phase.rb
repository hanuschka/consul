class Ai::Tools::ProjektImports::RemoveImportPhase < RubyLLM::Tool
  description "Removes one phase from the project import. Only call this when the user " \
              "explicitly asked for the phase to be deleted."

  params(
    type: "object",
    properties: {
      phase_index: {
        type: "integer",
        description: "Zero based index of the phase, as returned by read_import_data"
      }
    },
    required: %w[phase_index],
    additionalProperties: false
  )

  def initialize(editor:)
    @editor = editor
  end

  def name
    "remove_import_phase"
  end

  def execute(phase_index:)
    removed = @editor.remove_phase(phase_index)

    { status: "removed", phase_type: removed["type"] }
  rescue ::ProjektImports::AiResultEditor::IndexError => e
    { error: e.message }
  end
end
