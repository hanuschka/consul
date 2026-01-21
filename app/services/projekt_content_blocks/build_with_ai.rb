class ProjektContentBlocks::BuildWithAi < ApplicationService
  attr_reader :projekt

  def initialize(text:, projekt:)
    @text = text
    @projekt = projekt
  end

  def call
    base_prompt = fetch_base_prompt

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .ask(build_prompt(base_prompt, @text))

    content_blocks_data = response.content

    if content_blocks_data.present? && content_blocks_data['content_blocks'].present?
      categories = Array(content_blocks_data['categories']).compact
      sdg_codes = Array(content_blocks_data['sdg_codes']).compact

      ServiceResult.success(
        blocks: content_blocks_data['content_blocks'],
        projekt_start_date: content_blocks_data['projekt_start_date'],
        projekt_end_date: content_blocks_data['projekt_end_date'],
        categories: categories,
        sdg_codes: sdg_codes
      )
    else
      ServiceResult.failure(error: "KI konnte keine Struktur erstellen")
    end
  rescue => e
    ServiceResult.failure(error: "Fehler bei der KI-Verarbeitung: #{e.message}")
  end

  def fetch_base_prompt
    response =
      DtApi::Client.new
        .consul_ai_prompts
        .get(:projekt_import)

    response.dig('consul_ai_prompt', "prompt")
  end

  private

  def build_prompt(base_prompt, document_text)
    categories_examples = fetch_categories_examples
    sdg_goals_reference = fetch_sdg_goals_reference
    sdg_targets_info = fetch_sdg_targets_info

    <<~PROMPT
      #{base_prompt}
      For each logical section of the document, create an separated HTML content block that properly represents the content.
      If the document mentions projekt start or end dates, extract them and include in your response as `projekt_start_date` and `projekt_end_date`, otherwise keep those fields empty.

      Additionally, analyze the document content and identify:

      1. Categories (tags): Concise German words describing the project topic/theme (max 3-5 categories).
         #{categories_examples}

      2. SDG codes (UN Sustainable Development Goals): Only include codes that clearly and directly apply to the project content.
         Format as strings:
         - Goal level: "1" to "17" (e.g., "4" = Quality Education, "11" = Sustainable Cities, "13" = Climate Action)
         - Target level: "X.Y" (e.g., "4.1", "11.2")

         #{sdg_goals_reference}

         #{sdg_targets_info}

         Only return codes with clear evidence in the document. If uncertain, leave empty.

      Document text:
      #{document_text}
    PROMPT
  end

  def fetch_categories_examples
    existing_tags = Tag.order('taggings_count DESC NULLS LAST').pluck(:name)

    if existing_tags.any?
      "Examples from existing categories: #{existing_tags.map { |t| "\"#{t}\"" }.join(', ')}"
    end
  end

  def fetch_sdg_goals_reference
    goals = SDG::Goal.order(:code).map { |goal| "#{goal.code} = #{goal.title}" }
    if goals.any?
      "Available SDG Goals:\n         #{goals.join(",\n         ")}"
    end
  end

  def fetch_sdg_targets_info
    targets_count = SDG::Target.count
    if targets_count > 0
      sample_targets = SDG::Target.order(:code).limit(5).pluck(:code).join(', ')
      "Available targets include codes like: #{sample_targets}, etc. (#{targets_count} total targets)"
    end
  end

  def output_schema
    {
      type: "object",
      properties: {
        content_blocks: {
          type: "array",
          items: {
            type: "object",
            properties: {
              html: { type: "string" }
            },
            required: ["html"],
            additionalProperties: false
          }
        },
        projekt_start_date: {
          type: ["string", "null"],
          description: "ISO 8601 date format (YYYY-MM-DD) for projekt start date, if mentioned in document"
        },
        projekt_end_date: {
          type: ["string", "null"],
          description: "ISO 8601 date format (YYYY-MM-DD) for projekt end date, if mentioned in document"
        },
        categories: {
          type: "array",
          items: { type: "string" },
          description: "Array of category/tag names that describe the project topic or theme"
        },
        sdg_codes: {
          type: "array",
          items: { type: "string" },
          description: "Array of SDG codes (e.g., '1', '2.1', '17') applicable to this project"
        }
      },
      required: ["content_blocks", "projekt_start_date", "projekt_end_date", "categories", "sdg_codes"],
      additionalProperties: false
    }
  end
end
