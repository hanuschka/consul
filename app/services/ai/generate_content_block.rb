class Ai::GenerateContentBlock < ApplicationService
  def initialize(instructions, content_block_html, title = nil, subtitle = nil, projekt: nil, use_full_projekt_context: false)
    @instructions = instructions
    @content_block_html = content_block_html
    @title = title
    @subtitle = subtitle
    @projekt = projekt
    @use_full_projekt_context = use_full_projekt_context
  end

  def call
    projekt_context_text =
      if @use_full_projekt_context && @projekt.present?
        <<~TEXT
          Full projekt context:
          #{full_projekt_context(@projekt)}
        TEXT
      else
        ""
      end

    prompt = <<~TEXT
      #{fetch_prompt}

      Additional context of content block:
      It's content block of projekt with title: "#{@title}" and subtitle: "#{@subtitle}"

      #{projekt_context_text}

      Instructions: "#{@instructions}"

      Current content block HTML:
      #{@content_block_html}
    TEXT

    llm_response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .ask(prompt)

    llm_response.content["html"]
  end

  def fetch_prompt
    cache_key = "dt_api/consul_ai_prompts/content_block_ai_edit"

    parsed_response = DtApi::Caching.get_with_cache(
      cache_key,
      error_callback: -> { raise "DT API error: Failed to fetch content_block_ai_edit prompt and no cached version available" }
    ) do
      DtApi::Client.new.consul_ai_prompts.get(:content_block_ai_edit)
    end

    parsed_response.dig("consul_ai_prompt", "prompt")
  end

  def output_schema
    {
      type: 'object',
      properties: {
        html: { type: 'string' },
      },
      required: ['html'],
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
