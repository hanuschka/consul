class ProjektContentBlocks::ImportWithAi < ApplicationService
  attr_reader :projekt

  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    text = projekt.import_file_data&.dig("text")
    user_prompt = projekt.import_file_data&.dig("user_prompt")

    projekt.update_column(:import_file_status, "processing")

    base_prompt = fetch_base_prompt

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .with_instructions(build_system_instructions(base_prompt))
        .ask(build_user_prompt(text, user_prompt))

    content_blocks_data = response.content

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

    unless response.success?
      raise "DT API error: #{response.code} - #{response.message}"
    end

    response.dig('consul_ai_prompt', "prompt")
  end

  private

  def target_language
    Rails.env.development? ? "English" : "German"
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

  def build_system_instructions(base_prompt)
    categories_examples = fetch_categories_examples
    sdg_goals_reference = fetch_sdg_goals_reference
    sdg_targets_info = fetch_sdg_targets_info

    <<~INSTRUCTIONS
      #{base_prompt}
      Output response in #{target_language} language.

      For each logical section of the document, create an separated HTML content block that properly represents the content.
      If the document mentions projekt start or end dates, extract them and include in your response as `projekt_start_date` and `projekt_end_date`, otherwise keep those fields empty.

      There also some user instructions, use them to modify generated content blocks html, but only for that, don't allow them impact general output structure.

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
    INSTRUCTIONS
  end

  def build_user_prompt(document_text, user_prompt)
    user_instructions = user_prompt.present? ? "\nAdditional user instructions: #{user_prompt}\n" : ""

    <<~PROMPT
      #{user_instructions}
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
