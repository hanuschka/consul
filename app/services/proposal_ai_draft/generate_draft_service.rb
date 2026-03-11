class ProposalAiDraft::GenerateDraftService < ApplicationService
  def initialize(idea_text:, projekt_phase:)
    @idea_text = idea_text
    @projekt_phase = projekt_phase
  end

  def call
    projekt_name = @projekt_phase.projekt.page.title
    system_instructions = build_system_instructions(projekt_name)
    user_prompt = build_user_prompt(projekt_name)

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .with_instructions(system_instructions)
        .ask(user_prompt)

    response.content
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] GenerateDraftService failed: #{e.class} - #{e.message}")
    Rails.logger.error("[ProposalAiDraft] Backtrace: #{e.backtrace.first(10).join("\n")}")
    raise e
  end

  private

    def fetch_system_prompt
      parsed_response = DtApi::Client.new(use_cache: true).consul_ai_prompts.get(:proposal_generate_with_ai).parsed_response
      parsed_response.dig("consul_ai_prompt", "prompt")
    end

    def build_system_instructions(projekt_name)
      system_prompt = fetch_system_prompt
      raise "[ProposalAiDraft] System prompt not found for proposal_generate_with_ai" if system_prompt.nil?

      system_prompt.gsub("{{projekt_name}}", projekt_name)
    end

    def build_user_prompt(projekt_name)
      <<~PROMPT
        Project name: #{projekt_name}

        The citizen described their idea as:
        "#{@idea_text}"
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          title: {
            type: "string",
            description: "A concise, compelling title for the citizen proposal."
          },
          description: {
            type: "string",
            description: "A detailed description of the proposal explaining the problem, solution, and expected impact. Should be written in HTML format."
          },
          tag_list: {
            type: "string",
            description: "A comma-separated list of relevant tags categorizing the proposal topic."
          },
          image_prompt: {
            type: "string",
            description: "A descriptive prompt for generating a representative image for the proposal. Should be vivid and specific."
          },
          location: {
            type: ["string", "null"],
            description: "The geographic location relevant to the proposal (e.g. street, district, city). Null if not location-specific."
          }
        },
        required: ["title", "description", "tag_list", "image_prompt", "location"],
        additionalProperties: false
      }
    end
end
