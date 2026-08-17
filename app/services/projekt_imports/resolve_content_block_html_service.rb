class ProjektImports::ResolveContentBlockHtmlService < ApplicationService
  attr_reader :blocks, :phase_links, :image_urls, :sentry_context

  def initialize(blocks:, phase_links: [], image_urls: [], sentry_context: {})
    @blocks = Array(blocks)
    @phase_links = Array(phase_links)
    @image_urls = Array(image_urls)
    @sentry_context = sentry_context
  end

  def call
    return ServiceResult.success(blocks: []) if blocks.blank?

    input_blocks = build_input_blocks(fetch_templates)

    if input_blocks.blank?
      return ServiceResult.success(
        blocks: blocks.map { |block| { "html" => wrap_plain(block["content_data"]) } },
        unused_image_urls: image_urls,
        templates_available: false
      )
    end

    resolved_by_index = resolve_all(input_blocks).index_by { |block| block["index"] }

    resolved_blocks = blocks.each_with_index.map do |block, index|
      html = sanitizer.sanitize(resolved_by_index[index]&.dig("html").to_s)
      { "html" => html.presence || wrap_plain(block["content_data"]) }
    end

    filled = fill_image_slots(resolved_blocks)

    ServiceResult.success(
      blocks: filled[:blocks],
      unused_image_urls: image_urls.drop(filled[:used]),
      templates_available: true
    )
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ResolveContentBlockHtmlService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: sentry_context.merge(stage: "resolve_content_blocks")) if defined?(Sentry)
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.resolve_content_blocks_failed", message: e.message))
  end

  private

  def sanitizer
    @sanitizer ||= AdminWYSIWYGSanitizer.new
  end

  def fetch_templates
    ids = blocks.map { |block| block["template_id"] }.compact.uniq
    return {} if ids.empty?

    ProjektImports::ReferencesBuilder.fetch_content_block_templates
      .select { |template| ids.include?(template["id"]) }
      .index_by { |template| template["id"] }
  end

  def build_input_blocks(templates)
    results = []

    blocks.each_with_index do |block, index|
      template = templates[block["template_id"]]
      next if template.blank?

      results << {
        "index" => index,
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
      - Output only semantic, inline-styled HTML that matches the template: use H3/H4 for headings (never H1 or H2), <p> for paragraphs, and <ul>/<li> or <ol>/<li> for lists. Do not add <style> or <script> tags, JavaScript, forms, or input elements. #{image_source_rule} Use FontAwesome or Unicode icons (→ ✓ •).
      - Convert every URL and email address in the content into an anchor tag: web links as <a href="URL" target="_blank" rel="noopener noreferrer">label</a> (prefix "https://" when the URL has no scheme); emails as <a href="mailto:ADDRESS">ADDRESS</a>.
      #{phase_links_instruction}
      Input blocks:
      #{JSON.generate(input_blocks)}
    PROMPT

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema, feature: "projekt_imports.resolve_content_block_html")
        .ask(message)

    Array(response.content["blocks"])
  end

  # The model is never shown the real addresses, whether or not the document had
  # images: every src it writes is a placeholder, and fill_image_slots swaps the
  # placeholders for the stored images afterwards. Handing it the addresses
  # instead only adds ways for them to come back shortened, reordered or used
  # twice, none of which is visible in the output.
  def image_source_rule
    "Keep every image the template contains, and give each one a placeholder " \
      "URL sized to its slot (e.g. https://placehold.co/1200x500) — never a real " \
      "or external image source, and never a filename from the document."
  end

  # Slots are filled across blocks in order, so the first picture in the document
  # lands in the first block that has room for one.
  def fill_image_slots(resolved_blocks)
    return { blocks: resolved_blocks, used: 0 } if image_urls.blank?

    used = 0

    filled_blocks = resolved_blocks.map do |block|
      result = HtmlImageSlots.fill(block["html"], image_urls.drop(used))
      used += result[:used]

      { "html" => result[:html] }
    end

    { blocks: filled_blocks, used: used }
  end

  # Left-hand links to a participation phase were previously invented as
  # /projects/<slug>/phases/<id>, which is not a route at all. The real deep
  # links are passed in ready to use — the model must never build one.
  def phase_links_instruction
    return "" if phase_links.blank?

    <<~INSTRUCTION.strip
      - When a block's content refers to a participation phase (a call to
        participate, vote, submit, comment or attend), link it with the matching
        URL from this list, copied verbatim. Never construct a phase URL
        yourself and never link to a phase that is not listed:
        #{JSON.generate(phase_links)}
    INSTRUCTION
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
