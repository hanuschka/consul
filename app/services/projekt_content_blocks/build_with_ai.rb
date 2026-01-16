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
      ServiceResult.success(
        blocks: content_blocks_data['content_blocks'],
        projekt_start_date: content_blocks_data['projekt_start_date'],
        projekt_end_date: content_blocks_data['projekt_end_date']
      )
    else
      ServiceResult.failure(error: "KI konnte keine Struktur erstellen")
    end
  rescue => e
    # binding.pry
    # ServiceResult.failure(error: "Fehler bei der KI-Verarbeitung: #{e.message}")
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
    <<~PROMPT
      #{base_prompt}
      For each logical section of the document, create an separated HTML content block that properly represents the content.
      If the document mentions projekt start or end dates, extract them and include in your response as `projekt_start_date` and `projekt_end_date`, otherwise keep those fields empty.
      Document text:
      #{document_text}
    PROMPT
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
        }
      },
      required: ["content_blocks", "projekt_start_date", "projekt_end_date"],
      additionalProperties: false
    }
  end
end
