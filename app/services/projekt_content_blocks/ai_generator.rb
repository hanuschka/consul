class ProjektContentBlocks::AiGenerator
  attr_reader :projekt

  def initialize(projekt:)
    @projekt = projekt
  end

  def generate(task_instructions:, user_prompt:)
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
        .with_instructions(build_system_instructions(base_prompt, dt_templates_by_category, task_instructions))
        .ask(user_prompt)

    process_response(response.content)
  end

  private

  def process_response(content_blocks_data)
    if content_blocks_data.present? && content_blocks_data['content_blocks'].present?
      categories = Array(content_blocks_data['categories']).compact
      sdg_codes = Array(content_blocks_data['sdg_codes']).compact

      update_projekt_dates(content_blocks_data['projekt_start_date'], content_blocks_data['projekt_end_date'])
      update_projekt_categories(categories)
      valid_sdg_codes = update_projekt_sdgs(sdg_codes)
      content_blocks_data_result = create_content_blocks(content_blocks_data['content_blocks'])

      projekt.update_columns(
        import_file_status: "completed",
        import_file_data: {
          content_blocks: content_blocks_data_result,
          categories: categories,
          sdg_codes: valid_sdg_codes
        }
      )

      ServiceResult.success(
        blocks: content_blocks_data['content_blocks'],
        projekt_start_date: content_blocks_data['projekt_start_date'],
        projekt_end_date: content_blocks_data['projekt_end_date'],
        categories: categories,
        sdg_codes: sdg_codes
      )
    else
      projekt.update_columns(
        import_file_status: "failed",
        import_file_data: { error: { message: "KI konnte keine Struktur erstellen" } }
      )
      ServiceResult.failure(error: "KI konnte keine Struktur erstellen")
    end
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

  def build_system_instructions(base_prompt, dt_templates_by_category, task_instructions)
    categories_examples = fetch_categories_examples
    sdg_goals_reference = fetch_sdg_goals_reference
    sdg_targets_info = fetch_sdg_targets_info
    templates_reference = build_templates_reference(dt_templates_by_category)

    <<~INSTRUCTIONS
      #{base_prompt}
      Output response in #{target_language} language.

      #{task_instructions}

      #{templates_reference}

      Additionally, analyze the content and identify:

      1. Categories (tags): Concise German words describing the project topic/theme (max 3-5 categories).
         #{categories_examples}

      2. SDG codes (UN Sustainable Development Goals): Only include codes that clearly and directly apply to the project content.
         Format as strings:
         - Goal level: "1" to "17" (e.g., "4" = Quality Education, "11" = Sustainable Cities, "13" = Climate Action)
         - Target level: "X.Y" (e.g., "4.1", "11.2")

         #{sdg_goals_reference}

         #{sdg_targets_info}

         Only return codes with clear evidence in the content. If uncertain, leave empty.
    INSTRUCTIONS
  end

  def update_projekt_dates(start_date_str, end_date_str)
    updates = {}

    if start_date_str.present?
      begin
        updates[:total_duration_start] = Date.parse(start_date_str)
      rescue ArgumentError
      end
    end

    if end_date_str.present?
      begin
        updates[:total_duration_end] = Date.parse(end_date_str)
      rescue ArgumentError
      end
    end

    projekt.update(updates) if updates.any?
  end

  def update_projekt_categories(categories)
    return if categories.blank?

    projekt.tag_list.add(categories)
    projekt.save
  rescue => e
    Rails.logger.error("Failed to update projekt categories: #{e.message}")
  end

  def update_projekt_sdgs(sdg_codes)
    return [] if sdg_codes.blank?

    valid_codes = validate_sdg_codes(sdg_codes)
    return [] if valid_codes.blank?

    projekt.related_sdg_list = valid_codes.join(", ")
    projekt.save

    valid_codes
  rescue => e
    Rails.logger.error("Failed to update projekt SDGs: #{e.message}")
    []
  end

  def validate_sdg_codes(codes)
    codes.select do |code|
      if code.include?(".")
        SDG::Target.exists?(code: code) || SDG::LocalTarget.exists?(code: code)
      else
        SDG::Goal.exists?(code: code.to_i)
      end
    end
  end

  def create_content_blocks(blocks)
    blocks.map do |block_data|
      html = block_data['html']
      content_block = projekt.content_blocks.create!(
        name: "custom",
        body: html,
        key: "projekt_content_block_#{projekt.id}_#{projekt.content_blocks.count + 1}_#{DateTime.now.to_i}",
        locale: "de",
        margin_bottom: SiteCustomization::ContentBlock::DEFAULT_MARGIN_BOTTOM
      )
      { id: content_block.id, html: html }
    end
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
          description: "ISO 8601 date format (YYYY-MM-DD) for projekt start date, if mentioned"
        },
        projekt_end_date: {
          type: ["string", "null"],
          description: "ISO 8601 date format (YYYY-MM-DD) for projekt end date, if mentioned"
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
