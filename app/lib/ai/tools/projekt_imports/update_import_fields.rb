class Ai::Tools::ProjektImports::UpdateImportFields < RubyLLM::Tool
  description "Updates top level fields of the project import. Every field must be " \
              "present in the call: send null for each field you are NOT changing and " \
              "it keeps its stored value. To clear a text field send an empty string, " \
              "not null. To clear a list send an empty array."

  params(
    type: "object",
    properties: {
      title: { type: %w[string null], description: "Project title" },
      subtitle: { type: %w[string null], description: "Project subtitle or tagline" },
      projekt_start_date: { type: %w[string null], description: "ISO 8601 date (YYYY-MM-DD)" },
      projekt_end_date: { type: %w[string null], description: "ISO 8601 date (YYYY-MM-DD)" },
      categories: {
        type: %w[array null],
        items: { type: "string" },
        description: "Complete replacement list of category names"
      },
      sdg_codes: {
        type: %w[array null],
        items: { type: "string" },
        description: "Complete replacement list of SDG codes"
      },
      image_prompt: { type: %w[string null], description: "English prompt for AI image generation" }
    },
    required: %w[
      title subtitle projekt_start_date projekt_end_date
      categories sdg_codes image_prompt
    ],
    additionalProperties: false
  )

  def initialize(editor:)
    @editor = editor
  end

  def name
    "update_import_fields"
  end

  def execute(**attributes)
    changed = @editor.update_fields(attributes.stringify_keys)

    return { status: "no_changes" } if changed.empty?

    { status: "updated", changed_fields: changed }
  end
end
