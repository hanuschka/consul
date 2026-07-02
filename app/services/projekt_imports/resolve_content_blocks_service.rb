class ProjektImports::ResolveContentBlocksService < ApplicationService
  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    data = projekt_import.ai_result
    blocks = data["content_blocks"]
    return ServiceResult.success(ai_result: data) if blocks.blank?

    templates = fetch_templates(blocks)
    input_blocks = build_input_blocks(blocks, templates)

    if input_blocks.blank?
      data["content_blocks"] = blocks.map { |b| { "html" => wrap_plain(b["content_data"]) } }
      projekt_import.update!(ai_result: data)
      return ServiceResult.success(ai_result: data)
    end

    resolved_by_index = resolve_all(input_blocks).index_by { |b| b["index"] }

    data["content_blocks"] = blocks.each_with_index.map do |block, i|
      html = AdminWYSIWYGSanitizer.new.sanitize(resolved_by_index[i]&.dig("html").to_s)
      { "html" => html.presence || wrap_plain(block["content_data"]) }
    end

    projekt_import.update!(ai_result: data)

    ServiceResult.success(ai_result: data)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ResolveContentBlocksService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import.id, stage: "resolve_content_blocks" }) if defined?(Sentry)
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.resolve_content_blocks_failed", message: e.message))
  end

  private

  def fetch_templates(blocks)
    ids = blocks.map { |b| b["template_id"] }.compact.uniq
    return {} if ids.empty?

    ProjektImports::ReferencesBuilder.fetch_content_block_templates
      .select { |template| ids.include?(template["id"]) }
      .index_by { |template| template["id"] }
  end

  def build_input_blocks(blocks, templates)
    results = []

    blocks.each_with_index do |block, i|
      template = templates[block["template_id"]]
      next if template.blank?

      results << {
        "index" => i,
        "template_id" => block["template_id"],
        "template_html" => template["content"] || template["html"] || "",
        "content_data" => block["content_data"]
      }
    end

    results
  end

  def resolve_all(input_blocks)
    message = <<~PROMPT
      Fill each HTML template with its provided content. Each template shows the desired STYLING and STRUCTURE by example — the number of items it contains is only illustrative, NOT a fixed count.
      - Keep each template's wrapper, tags, CSS classes, and inline styles; match its visual design exactly.
      - Repeated elements (list items <li>, cards, rows, columns) are a REUSABLE PATTERN: render exactly one per content entry. If the content has more entries than the template illustrates, duplicate the example item's markup (identical tags, classes, and styles) for each additional entry; if it has fewer, drop the surplus example items. The number of rendered items MUST equal the number of content entries — never output an empty item, and never drop, truncate, or merge content to fit the template's example count.
      - Replace all sample text with the real content; do not keep the template's placeholder wording.
      - Output only semantic, inline-styled HTML that matches the template: use H3/H4 for headings (never H1 or H2), <p> for paragraphs, and <ul>/<li> or <ol>/<li> for lists. Do not add <style> or <script> tags, JavaScript, forms, or input elements. Any image must use a placeholder URL only (e.g. https://placehold.co/1200x500) — never a real or external image source. Use FontAwesome or Unicode icons (→ ✓ •).
      - Convert every URL and email address in the content into an anchor tag: web links as <a href="URL" target="_blank" rel="noopener noreferrer">label</a> (prefix "https://" when the URL has no scheme); emails as <a href="mailto:ADDRESS">ADDRESS</a>.

      Input blocks:
      #{JSON.generate(input_blocks)}
    PROMPT

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .ask(message)

    Array(response.content["blocks"])
  end

  def output_schema
    {
      type: "object",
      properties: {
        blocks: {
          type: "array",
          items: {
            type: "object",
            properties: {
              index: { type: "integer", description: "Block index from input" },
              html: { type: "string", description: "Filled HTML template" }
            },
            required: %w[index html],
            additionalProperties: false
          }
        }
      },
      required: %w[blocks],
      additionalProperties: false
    }
  end

  def wrap_plain(text)
    "<div><p>#{ERB::Util.html_escape(text.to_s)}</p></div>"
  end
end
