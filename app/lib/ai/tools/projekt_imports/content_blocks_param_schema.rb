# Reuses the extraction schema's content block shape so the chat and the initial
# analysis stay describable by one definition. Lazy for the same reason as its
# siblings: OutputSchemaBuilder is resolved on first tool use, not at load.
class Ai::Tools::ProjektImports::ContentBlocksParamSchema
  def to_json_schema
    {
      type: "object",
      properties: {
        content_blocks: {
          type: "array",
          description: "Complete, ordered replacement list of content blocks",
          items: ::ProjektImports::OutputSchemaBuilder.content_block_item_schema
        }
      },
      required: %w[content_blocks],
      additionalProperties: false
    }
  end
end
