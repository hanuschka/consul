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

    def build_prompt(projekt_name, criteria_texts)
      criteria_list = criteria_texts.map.with_index(1) { |c, i| "#{i}. #{c}" }.join("\n")
      <<~PROMPT
        You are helping a citizen write a proposal for the participatory project "#{projekt_name}".

        The citizen described their idea as:
        "#{@idea_text}"

        The proposal must meet these criteria:
        #{criteria_list}

        Generate a well-structured proposal with:
        - A concise, engaging title (max 80 characters)
        - A clear description (3-5 sentences explaining the idea, its benefit, and feasibility)
        - Relevant tags as a comma-separated list (max 5 tags)
        - A brief image prompt for generating a banner image that visually represents the proposal

        Respond in the same language as the citizen's idea.
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          title:        { type: "string" },
          description:  { type: "string" },
          tag_list:     { type: "string" },
          image_prompt: { type: "string" }
        },
        required: ["title", "description", "tag_list", "image_prompt"],
        additionalProperties: false
      }
    end
end
