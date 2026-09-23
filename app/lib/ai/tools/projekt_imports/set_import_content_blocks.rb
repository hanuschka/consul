class Ai::Tools::ProjektImports::SetImportContentBlocks < Ai::Tools::ProjektImports::EditorTool
  description "Proposes a replacement for the whole content block list of the project " \
              "import. Read the current blocks with read_import_data first and send " \
              "them all back in order, with only the parts the user asked to change " \
              "modified. The blocks are NOT replaced by this call: the administrator " \
              "sees the proposal under your message and applies or discards it with a " \
              "button. Call it once per requested change."

  params Ai::Tools::ProjektImports::ContentBlocksParamSchema.new

  def execute(content_blocks:)
    proposal = editor.propose_content_blocks(content_blocks.map(&:deep_stringify_keys))

    {
      status: "proposed",
      proposal_id: proposal["proposal_id"],
      content_block_count: proposal.dig("details", "count"),
      note: "Not replaced yet. Tell the user in one sentence to confirm the new " \
            "block list with the Apply button shown under this message."
    }
  rescue ::ProjektImports::AiResultEditor::ResolvedContentBlocksError => e
    { error: e.message }
  end
end
