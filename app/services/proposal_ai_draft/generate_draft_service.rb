class ProposalAiDraft::GenerateDraftService < ApplicationService
  def initialize(idea_text:, projekt_phase:)
    @idea_text = idea_text
    @projekt_phase = projekt_phase
  end

  def call
    criteria_texts = @projekt_phase.proposal_criteria.pluck(:text)
    projekt_name = @projekt_phase.projekt.page.title
    prompt = build_prompt(projekt_name, criteria_texts)
    response = Ai::RubyLlmFactory.chat_with_json_output(output_schema).ask(prompt)
    response.content
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] GenerateDraftService failed: #{e.class} - #{e.message}")
    Rails.logger.error("[ProposalAiDraft] Backtrace: #{e.backtrace.first(10).join("\n")}")
    raise e
  end

  private

    def fetch_system_prompt
      cache_key = "dt_api/consul_ai_prompts/proposal_generate_with_ai"

      parsed_response = DtApi::Caching.get_with_cache(cache_key) do
        DtApi::Client.new.consul_ai_prompts.get(:proposal_generate_with_ai)
      end

      parsed_response.dig("consul_ai_prompt", "prompt")
    end

    def build_prompt(projekt_name, criteria_texts)
      system_prompt = fetch_system_prompt
      raise "[ProposalAiDraft] System prompt not found for proposal_generate_with_ai" if system_prompt.nil?

      criteria_list = criteria_texts.map.with_index(1) { |c, i| "#{i}. #{c}" }.join("\n")
      dynamic_context = <<~CONTEXT
        Project name: #{projekt_name}

        The citizen described their idea as:
        "#{@idea_text}"

        The proposal must meet these criteria:
        #{criteria_list}
      CONTEXT

      "#{system_prompt}\n#{dynamic_context}"
    end

    def output_schema
      {
        type: "object",
        properties: {
          title:        { type: "string" },
          description:  { type: "string" },
          tag_list:     { type: "string" },
          image_prompt: { type: "string" },
          location:     { type: ["string", "null"] }
        },
        required: ["title", "description", "tag_list", "image_prompt", "location"],
        additionalProperties: false
      }
    end
end
