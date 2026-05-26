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

    resolved_by_index = resolve_all(input_blocks).index_by { it["index"] }

    data["content_blocks"] = blocks.each_with_index.map do |block, i|
      html = resolved_by_index[i]&.dig("html")
      { "html" => html.presence || wrap_plain(block["content_data"]) }
    end

    projekt_import.update!(ai_result: data)

    ServiceResult.success(ai_result: data)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ResolveContentBlocksService] failed: #{e.message}")
    ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.resolve_content_blocks_failed", message: e.message))
  end

  private

  def fetch_templates(blocks)
    ids = blocks.map { it["template_id"] }.compact.uniq
    return {} if ids.empty?

    response = DtApi::Client.new(use_cache: true).content_block_templates.all(section: "projekt_page")
    body = response.parsed_response
    list = Array(body.is_a?(Hash) ? body["content_block_templates"] : body)

    list.select { |t| ids.include?(t["id"]) }.index_by { it["id"] }
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
      Fill each HTML template with its provided content.
      Replace ALL placeholder text with the actual content.
      Keep HTML structure, CSS classes, and attributes exactly as they are.
      Only replace text content — never modify tags, classes, or attributes.

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
