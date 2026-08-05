class Ai::EditContentBlock < ApplicationService
  def initialize(
    instructions, content_block_html, title = nil, subtitle = nil, projekt: nil,
    use_full_projekt_context: false, allow_text_modification: false
)
    @instructions = instructions
    @content_block_html = content_block_html
    @title = title
    @subtitle = subtitle
    @projekt = projekt
    @use_full_projekt_context = use_full_projekt_context
    @allow_text_modification = allow_text_modification
  end

  def call
    llm_response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .with_instructions(system_instructions)
        .ask(user_prompt)

    AdminWYSIWYGSanitizer.new.sanitize(llm_response.content["html"])
  end

  private

  def system_instructions
    text_modification_instruction =
      if @allow_text_modification
        "You CAN modify the text content of the content block if the instructions require it."
      else
        "IMPORTANT: You MUST NOT modify the text content. Only modify the HTML structure, styling, layout, and organization. Keep all existing text content exactly as it is."
      end

    <<~TEXT
      #{fetch_prompt}

      #{text_modification_instruction}

      Output response in #{target_language} language.
    TEXT
  end

  def user_prompt
    projekt_context_text =
      if @use_full_projekt_context && @projekt.present?
        <<~TEXT
          Full projekt context:
          #{full_projekt_context(@projekt)}
        TEXT
      else
        ""
      end

    <<~TEXT
      Additional context of content block:
      It's content block of projekt with title: "#{@title}" and subtitle: "#{@subtitle}"

      #{projekt_context_text}

      Instructions: "#{@instructions}"

      Current content block HTML:
      #{@content_block_html}
    TEXT
  end

  # Called inline from the controller, so the request locale is still the
  # editor's own — unlike generation, which is dispatched to a job.
  def target_language
    Ai::OutputLanguage.name_for(I18n.locale)
  end

  def fetch_prompt
    parsed_response =
      DtApi::Client.new(use_cache: true)
        .consul_ai_prompts
        .get(:content_block_ai_edit)
        .parsed_response

    parsed_response.dig("consul_ai_prompt", "prompt")
  end

  def output_schema
    {
      type: "object",
      properties: {
        html: { type: "string" }
      },
      required: ["html"],
      additionalProperties: false
    }
  end

  def full_projekt_context(projekt)
    content_blocks_text =
      projekt
        .content_blocks
        .order(:position)
        .map do |content_block|
          body_text = ActionController::Base.helpers.strip_tags(content_block.body.to_s).squish

          <<~TEXT.squish
            Content block ##{content_block.position} (id: #{content_block.id}, margin_bottom: #{content_block.margin_bottom}): #{body_text}
          TEXT
        end
        .join("\n")

    phases_text =
      projekt
        .projekt_phases
        .order(:given_order, :id)
        .map do |phase|
          name = phase.phase_tab_name.to_s.squish
          type = phase.type.to_s
          start_date = phase.start_date
          end_date = phase.end_date

          <<~TEXT.squish
            Phase (id: #{phase.id}, type: #{type}, name: #{name}, start_date: #{start_date}, end_date: #{end_date})
          TEXT
        end
        .join("\n")

    tags_text = projekt.tags_list.map(&:name).join(", ")

    <<~TEXT
      Projekt name: #{projekt.name}
      Projekt duration start: #{projekt.total_duration_start}
      Projekt duration end: #{projekt.total_duration_end}
      Projekt categories: #{tags_text}
      Projekt SDG goals: #{projekt.sdg_goal_list}
      Projekt SDG targets: #{projekt.sdg_target_list}
      Projekt related SDGs: #{projekt.related_sdg_list}
      Projekt phases: #{phases_text}
      Projekt content blocks: #{content_blocks_text}
    TEXT
  end
end
