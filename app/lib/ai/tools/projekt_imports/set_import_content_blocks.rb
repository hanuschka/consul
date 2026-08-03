class Ai::Tools::ProjektImports::SetImportContentBlocks < RubyLLM::Tool
  description "Replaces the whole content block list of the project import. Read the " \
              "current blocks with read_import_data first and send them all back in " \
              "order, with only the parts the user asked to change modified."

  params(
    type: "object",
    properties: {
      content_blocks: {
        type: "array",
        description: "Complete, ordered replacement list of content blocks",
        items: {
          type: "object",
          properties: {
            template_id: { type: "integer", description: "ID of the content block template" },
            content_data: { type: "string", description: "Text content for the template" }
          },
          required: %w[template_id content_data],
          additionalProperties: false
        }
      }
    },
    required: %w[content_blocks],
    additionalProperties: false
  )

  def initialize(editor:)
    @editor = editor
  end

  def name
    "set_import_content_blocks"
  end

  def execute(content_blocks:)
    count = @editor.replace_content_blocks(content_blocks.map(&:deep_stringify_keys))

    { status: "replaced", content_block_count: count }
  rescue ::ProjektImports::AiResultEditor::ResolvedContentBlocksError => e
    { error: e.message }
  end
end
