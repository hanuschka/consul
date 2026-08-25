# Shared base for the chat's import-editing tools. RubyLLM derives a tool's
# advertised name from the full constant path, which would produce
# "ai--tools--projekt_imports--add_import_phase"; the demodulized name is what
# the system prompt tells the model to call.
class Ai::Tools::ProjektImports::EditorTool < RubyLLM::Tool
  attr_reader :editor

  def initialize(editor:)
    @editor = editor
  end

  def name
    self.class.name.demodulize.underscore
  end
end
