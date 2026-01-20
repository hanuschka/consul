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
    existing_tags = Tag.order('taggings_count DESC NULLS LAST').limit(15).pluck(:name)
    if existing_tags.any?
      "Examples from existing categories: #{existing_tags.map { |t| "\"#{t}\"" }.join(', ')}"
    else
      "Examples: \"Bildung\", \"Umwelt\", \"Infrastruktur\", \"Gesundheit\", \"Mobilität\", \"Soziales\""
    end
  end

  def fetch_sdg_goals_reference
    goals = SDG::Goal.order(:code).map { |goal| "#{goal.code} = #{goal.title}" }
    if goals.any?
      "Available SDG Goals:\n         #{goals.join(",\n         ")}"
    else
      "SDG Goals: 1-17"
    end
  end

  def fetch_sdg_targets_info
    targets_count = SDG::Target.count
    if targets_count > 0
      sample_targets = SDG::Target.order(:code).limit(5).pluck(:code).join(', ')
      "Available targets include codes like: #{sample_targets}, etc. (#{targets_count} total targets)"
    else
      "Targets follow format: X.Y (e.g., 4.1, 11.2)"
    end
  end

  #def prompt
  #  # You are an assistant for structuring document content into HTML blocks.
  #    # - Make it more Visually appealing: clear visual hierarchy, cards/boxes, subtle shadows, rounded corners, and clearly recognizable calls to action

  #    # - Recognize the natural structure of the document
  #    # - Maintain hierarchical order
  #    # - Group related content together logically
  #    # - Only output valid HTML
  #    # - Escape special characters properly
  #    # - Keep formatting clean and semantic
  #    # - Each block should be a complete, self-contained HTML snippet
  #    # - Use only Foundation 6 classes for layout (e.g. `grid-container`, `grid-x`, `cell`, `callout`)

  #  <<~PROMPT


  #    Rules:

  #    # Consul HTML Block Creator

  #    Task: You need to Analyze the following document text and generate a list of HTML content blocks.
  #    You are a project manager of a citizen participation platform built with Consul. Your job is to turn project information into clear, citizen-friendly, visually appealing content that can be embedded directly into Consul pages.

  #    For each logical section of the document, create an HTML content block that properly represents the content.

  #    ## Requirements (very important)
  #    - Use semantic HTML to represent the document structure
  #    - Use inline styles only (no `<style>` tag, no external CSS files)
  #    - No JavaScript
  #    - Mobile-optimized: on small screens (smartphones), the layout must be single-column, easy to read, with generous spacing and touch-friendly buttons
  #    - Do not use H1 headings
  #    - Use H3 and/or H4 headings only for all headlines
  #    - Use <p> tags for paragraphs
  #    - Use <ul> and <li> tags for bulleted lists
  #    - Use <ol> and <li> tags for numbered lists
  #    - Avoid duplicate or semantically redundant heading levels
  #    - Use FontAwesome icons if available in Consul; otherwise use simple Unicode alternatives (→, ✓, •)
  #    - Images must be placeholders only (e.g. `https://placehold.co/1200x500`). Do not invent real image sources
  #    - Never create form inputs or feedback forms.

  #    ## Date Extraction
  #    - If the document mentions projekt start or end dates, extract them and include in your response as `projekt_start_date` and `projekt_end_date`
  #    - Dates must be in ISO 8601 format (YYYY-MM-DD)
  #    - Look for phrases like "Projektlaufzeit", "Zeitraum", "von ... bis", "Start", "Ende", "Beginn", "Abschluss", etc.
  #    - If dates are unclear or not mentioned, set them to null

  #    Document text:
  #    #{text}
  #  PROMPT
  #end

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
