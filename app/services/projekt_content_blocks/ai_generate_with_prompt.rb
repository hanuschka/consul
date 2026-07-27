class ProjektContentBlocks::AiGenerateWithPrompt < ApplicationService
  CONTENT_BLOCK_LOCALE = "de".freeze

  FAILURE_MESSAGE = "KI konnte keine Struktur erstellen".freeze

  TASK_INSTRUCTIONS = <<~TEXT.freeze
    Generate structured HTML content blocks based on the user's description.
    Create appropriate HTML content blocks that represent the project described by the user.
  TEXT

  attr_reader :projekt

  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    projekt.update_column(:import_file_status, "processing")

    base_prompt = fetch_base_prompt
    dt_templates_by_category = fetch_dt_templates

    chat = Ai::RubyLlmFactory.chat_with_json_output(output_schema)

    if dt_templates_by_category.any?
      templates_tool = Ai::Tools::FetchContentBlockTemplates.new(
        templates_by_category: dt_templates_by_category
      )
      chat.with_tool(templates_tool)
    end

    response =
      chat
        .with_instructions(build_system_instructions(base_prompt, dt_templates_by_category))
        .ask(user_prompt)

    process_response(response.content)
  end

  private

  def user_prompt
    projekt.import_file_data&.dig("prompt")
  end

  def process_response(response_data)
    blocks = response_data.present? ? response_data["content_blocks"] : nil

    if blocks.blank?
      return mark_failed
    end

    content_blocks = ProjektContentBlocks::Services::CreateFromImportData.call(
      projekt: projekt,
      blocks: blocks,
      locale: CONTENT_BLOCK_LOCALE
    )

    projekt.update_columns(
      import_file_status: "completed",
      import_file_data: { content_blocks: content_blocks }
    )

    ServiceResult.success(content_blocks: content_blocks)
  end

  def mark_failed
    projekt.update_columns(
      import_file_status: "failed",
      import_file_data: { error: { message: FAILURE_MESSAGE } }
    )

    ServiceResult.failure(error: FAILURE_MESSAGE)
  end

  def fetch_base_prompt
    response =
      DtApi::Client.new
        .consul_ai_prompts
        .get(:projekt_import)

    if !response.success?
      raise "DT API error: #{response.code} - #{response.message}"
    end

    response.dig('consul_ai_prompt', "prompt")
  end

  def target_language
    Rails.env.development? ? "English" : "German"
  end

  def build_system_instructions(base_prompt, dt_templates_by_category)
    <<~INSTRUCTIONS
      #{base_prompt}
      Output response in #{target_language} language.

      #{TASK_INSTRUCTIONS}

      #{build_templates_reference(dt_templates_by_category)}
    INSTRUCTIONS
  end

  def fetch_dt_templates
    response = DtApi::Client.new(use_cache: true)
      .content_block_templates
      .all

    return [] if !response.success?

    response.parsed_response.dig("content_block_templates_by_category") || []
  rescue => e
    Rails.logger.error("Failed to fetch DT templates: #{e.message}")
    []
  end

  def build_templates_reference(dt_templates_by_category)
    lines = []
    lines << "You MUST use the HTML from content block templates as the basis for every content block you generate."
    lines << "Do NOT invent your own HTML structures. Pick the most appropriate template for each section, fetch its HTML with the fetch_content_block_templates tool, and adapt it by replacing placeholder text with the actual content."

    if dt_templates_by_category.any?
      lines << ""
      lines << "Templates from demokratie.today:"
      dt_templates_by_category.each do |category_data|
        category_name = category_data.dig("category", "name_de") || category_data.dig("category", "name")
        templates = category_data["templates"] || []

        if templates.any?
          lines << "  Category: #{category_name}"
          templates.each do |template|
            template_info = "    - name: #{template['name']}, id: #{template['id']}"
            template_info += ", description: #{template['description']}" if template['description'].present?
            lines << template_info
          end
        end
      end
    else
      local_templates = fetch_local_templates_metadata
      lines << ""
      lines << "Local templates:"
      local_templates.each do |category_name, template_names|
        lines << "  Category: #{category_name}"
        template_names.each do |name|
          lines << "    - #{name}"
        end
      end
    end

    lines.join("\n")
  rescue => e
    Rails.logger.error("Failed to build templates reference: #{e.message}")
    ""
  end

  def fetch_local_templates_metadata
    selector = Projekts::ContentBlockTemplatesSelectorComponent.new
    {
      "Basic Content" => selector.basic_content_templates,
      "Status and Notes" => selector.status_and_notes_templates,
      "Teasers and Promotions" => selector.teasers_and_promotions,
      "Media and Resources" => selector.media_and_resources_templates,
      "Messages" => selector.messages_content_block_templates
    }
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
        }
      },
      required: ["content_blocks"],
      additionalProperties: false
    }
  end
end
