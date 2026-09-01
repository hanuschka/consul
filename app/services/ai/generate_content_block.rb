class Ai::GenerateContentBlock < ApplicationService
  class AiCancelledError < StandardError; end

  MAX_TOOL_ITERATIONS = 6

  def initialize(
    content_block:,
    projekt:,
    prompt:,
    category_hint: nil,
    anchor_template_id: nil,
    use_projekt_context: false,
    newsletter: nil,
    dt_template_section: nil,
    text_locale: nil
  )
    @content_block = content_block
    @projekt = projekt
    @prompt = prompt
    @category_hint = category_hint.presence
    @anchor_template_id = anchor_template_id.presence
    @use_projekt_context = use_projekt_context
    @newsletter = newsletter
    @dt_template_section = dt_template_section.presence
    @text_locale = text_locale.presence
  end

  def call
    raise_if_cancelled!
    mark_processing

    filtered_templates = []
    anchor_template = nil

    if @category_hint.present?
      dt_templates_by_category = fetch_dt_templates
      filtered_templates = filter_templates_by_category(dt_templates_by_category)
      anchor_template = fetch_anchor_template(dt_templates_by_category)
    end

    chat = Ai::RubyLlmFactory.chat_with_json_output(output_schema, feature: "content_blocks.generate")

    if filtered_templates.any?
      tool = Ai::Tools::FetchContentBlockTemplates.new(
        templates_by_category: filtered_templates
      )
      chat.with_tool(tool)
    end

    instructions = build_system_instructions(filtered_templates, anchor_template)

    raise_if_cancelled!

    response =
      chat
        .with_instructions(instructions)
        .ask(@prompt)

    raise_if_cancelled!

    body_html = response.content&.dig("html")

    if body_html.blank?
      ServiceResult.failure(error: "KI konnte keinen Inhalt erstellen")
    else
      apply_completion(body_html)
      ServiceResult.success(body_html: body_html, content_block_id: @content_block.id)
    end
  end

  private

  def raise_if_cancelled!
    return if @content_block.blank?

    fresh = SiteCustomization::ContentBlock.unscoped.find_by(id: @content_block.id)
    return if fresh.blank?

    raise AiCancelledError if fresh.ai_generation_status == "cancelled"
  end

  def mark_processing
    @content_block.mark_ai_generation_status!("processing")
  end

  def apply_completion(body_html)
    if replace_mode?
      @content_block.update_columns(
        body: body_html,
        ai_generation_data: nil
      )
    else
      ctx = (@content_block.ai_generation_data || {})["insertion_context"] || {}
      previous_id = ctx["previous_content_block_id"]
      add_at_top = ctx["add_at_top"]

      new_key =
        if @newsletter.present?
          "newsletter_content_block_#{@newsletter.id}_#{Time.current.to_i}_#{@content_block.id}"
        else
          "projekt_content_block_#{@projekt.id}_#{Time.current.to_i}_#{@content_block.id}"
        end

      @content_block.update_columns(
        body: body_html,
        key: new_key,
        ai_generation_data: nil
      )

      position_target = compute_target_position(previous_id, add_at_top)
      @content_block.insert_at(position_target) if position_target.present?
    end
  end

  def compute_target_position(previous_id, add_at_top)
    if previous_id.present?
      previous_block = SiteCustomization::ContentBlock.find_by(id: previous_id)
      return previous_block.position + 1 if previous_block.present?
    end

    return 1 if add_at_top

    nil
  end

  def replace_mode?
    (@content_block.ai_generation_data || {}).key?("prior_body")
  end

  def fetch_dt_templates
    response = DtApi::Client.new(use_cache: true).content_block_templates.all(section: @dt_template_section)

    return [] if !response.success?

    response.parsed_response.dig("content_block_templates_by_category") || []
  rescue => e
    Rails.logger.error("Failed to fetch DT templates: #{e.message}")
    []
  end

  def filter_templates_by_category(dt_templates_by_category)
    return dt_templates_by_category if @category_hint.blank?
    return dt_templates_by_category if dt_templates_by_category.blank?

    matched = dt_templates_by_category.select do |category_data|
      category_id = category_data.dig("category", "id").to_s
      name_de = category_data.dig("category", "name_de").to_s
      name = category_data.dig("category", "name").to_s

      [category_id, name_de.downcase, name.downcase].include?(@category_hint.to_s.downcase)
    end

    matched.presence || dt_templates_by_category
  end

  def fetch_anchor_template(dt_templates_by_category)
    return nil if @anchor_template_id.blank?
    return nil if dt_templates_by_category.blank?

    dt_templates_by_category.each do |category_data|
      templates = category_data["templates"] || []
      found = templates.find { |t| t["id"].to_s == @anchor_template_id.to_s }
      return found if found.present?
    end

    nil
  end

  def build_system_instructions(filtered_templates, anchor_template)
    base_prompt = fetch_base_prompt
    templates_reference = @category_hint.present? ? build_templates_reference(filtered_templates) : ""
    anchor_section = build_anchor_section(anchor_template)
    projekt_context_section = build_projekt_context_section
    newsletter_context_section = build_newsletter_context_section

    <<~INSTRUCTIONS
      #{base_prompt}

      You are creating exactly ONE new HTML content block for a Consul/Projekt page based on the user's prompt.
      Return only one HTML fragment in the `html` field of the JSON output. Do NOT include surrounding wrappers or scripts.

      IMPORTANT: You MUST NOT include any JavaScript in the output. No <script>
      tags, no inline event handlers (onclick, onload, etc.), no javascript:
      URLs. Output only pure HTML and CSS.

      Output response in #{target_language} language.

      #{templates_reference}

      #{anchor_section}

      #{projekt_context_section}

      #{newsletter_context_section}
    INSTRUCTIONS
  end

  def build_newsletter_context_section
    return "" if @newsletter.blank?

    existing_blocks_text =
      @newsletter
        .content_blocks
        .order(:position)
        .map do |content_block|
          body_text = ActionController::Base.helpers.strip_tags(content_block.body.to_s).squish

          "Content block ##{content_block.position}: #{body_text}".squish
        end
        .join("\n")

    <<~TEXT
      This content block is part of an EMAIL NEWSLETTER with the subject: "#{@newsletter.subject}".

      IMPORTANT email-safety requirements for the generated HTML:
      - Use table-based layout (nested <table> elements) instead of flexbox/grid.
      - Use only inline styles; do NOT rely on external CSS classes or frameworks.
      - Do not use <script>, <form>, <iframe> or interactive widgets.
      - Keep images responsive via width attributes and max-width:100% inline styles.

      Existing newsletter content blocks:
      #{existing_blocks_text}
    TEXT
  end

  def build_anchor_section(anchor_template)
    return "" if anchor_template.blank?

    <<~TEXT
      Anchor template:
      Name: #{anchor_template['name']}
      Description: #{anchor_template['description']}
      HTML:
      #{anchor_template['content']}
    TEXT
  end

  def build_projekt_context_section
    return "" if !@use_projekt_context
    return "" if @projekt.blank?

    <<~TEXT
      Full projekt context to inform the generated content block:
      #{Ai::EditContentBlock.new(nil, nil, projekt: @projekt).send(:full_projekt_context, @projekt)}
    TEXT
  end

  def build_templates_reference(templates_by_category)
    lines = []
    lines << "Use the following templates as inspiration. Pick the most relevant one and fetch its full HTML with the fetch_content_block_templates tool, then adapt it to the user's prompt."
    lines << "Limit tool calls to at most #{MAX_TOOL_ITERATIONS} iterations."

    if templates_by_category.any?
      lines << ""
      lines << "Templates from demokratie.today:"
      templates_by_category.each do |category_data|
        category_name = category_data.dig("category", "name_de") || category_data.dig("category", "name")
        templates = category_data["templates"] || []

        if templates.any?
          lines << "  Category: #{category_name}"
          templates.each do |template|
            info = "    - name: #{template['name']}, id: #{template['id']}"
            info += ", description: #{template['description']}" if template['description'].present?
            lines << info
          end
        end
      end
    else
      local_templates = fetch_local_templates_metadata
      lines << ""
      lines << "Local templates (names only — full HTML unavailable):"
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
    if @newsletter.present?
      return {
        "Email Defaults" => Newsletters::ContentBlockTemplatesSelectorComponent::EMAIL_TEMPLATE_NAMES
      }
    end

    selector = Projekts::ContentBlockTemplatesSelectorComponent.new
    {
      "Basic Content" => selector.basic_content_templates,
      "Status and Notes" => selector.status_and_notes_templates,
      "Teasers and Promotions" => selector.teasers_and_promotions,
      "Media and Resources" => selector.media_and_resources_templates,
      "Messages" => selector.messages_content_block_templates
    }
  end

  def fetch_base_prompt
    response = DtApi::Client.new(use_cache: true).consul_ai_prompts.get(:content_block_ai_create)

    return "" if !response.success?

    response.parsed_response.dig("consul_ai_prompt", "prompt").to_s
  rescue => e
    Rails.logger.error("Failed to fetch AI base prompt: #{e.message}")
    ""
  end

  # Runs in a background job, where I18n.locale is always the default: the
  # editor's locale has to arrive with the job payload or not at all.
  def target_language
    Ai::OutputLanguage.name_for(@text_locale)
  end

  def output_schema
    {
      type: "object",
      properties: {
        html: { type: "string", description: "Single HTML content block, no <script> tags." }
      },
      required: ["html"],
      additionalProperties: false
    }
  end
end
