class Ai::Tools::ProjektImports::SetImportContentBlocks < Ai::Tools::ProjektImports::EditorTool
  description "Replaces the whole content block list of the project import. Read the " \
              "current blocks with read_import_data first and send them all back in " \
              "order, with only the parts the user asked to change modified."

  params Ai::Tools::ProjektImports::ContentBlocksParamSchema.new

  def execute(content_blocks:)
    count = editor.replace_content_blocks(content_blocks.map(&:deep_stringify_keys))

    { status: "replaced", content_block_count: count }
  rescue ::ProjektImports::AiResultEditor::ResolvedContentBlocksError => e
    { error: e.message }
  end
end
