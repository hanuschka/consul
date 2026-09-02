class Ai::Tools::ProjektImports::ReadImportData < Ai::Tools::ProjektImports::EditorTool
  SECTIONS = %w[overview phases content_blocks].freeze

  description "Reads the current project import data. Call this before changing " \
              "anything, so you work from the stored values rather than from memory. " \
              "\"phases\" returns every phase in full, including its poll questions, " \
              "events, milestones, arguments, notifications and other resources."

  params(
    type: "object",
    properties: {
      section: {
        type: "string",
        enum: SECTIONS,
        description: "Which part of the import data to read"
      }
    },
    required: %w[section],
    additionalProperties: false
  )

  def execute(section:)
    case section
    when "overview" then { overview: editor.overview }
    when "phases" then { phases: editor.phases }
    when "content_blocks" then { content_blocks: editor.content_blocks }
    else { error: "Unknown section #{section}. Use one of: #{SECTIONS.join(", ")}" }
    end
  end
end
