class ProposalAiDraft::EvaluateSoftCriteriaService < ApplicationService
  DT_PROMPT_KEY = :proposal_evaluate_soft_criteria
  SCORE_MIN = 0
  SCORE_MAX = 25

  def initialize(resource:)
    @resource = resource
  end

  def call
    criteria = @resource.projekt_phase.user_resource_criteria.soft_kind.to_a
    return empty_result if criteria.empty?

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema, feature: "proposal_ai_draft.soft_criteria")
        .with_instructions(build_system_instructions)
        .ask(build_user_prompt(criteria))

    response.content
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] EvaluateSoftCriteriaService failed: #{e.class} - #{e.message}")
    Rails.logger.error("[ProposalAiDraft] Backtrace: #{e.backtrace.first(5).join("\n")}")
    raise e
  end

  private

    def empty_result
      { "total_score" => 0, "overall_feedback" => "", "criteria" => [] }
    end

    def fetch_system_prompt
      parsed = DtApi::Client.new(use_cache: true).consul_ai_prompts.get(DT_PROMPT_KEY).parsed_response
      parsed.dig("consul_ai_prompt", "prompt")
    end

    def build_system_instructions
      prompt = fetch_system_prompt
      raise "[ProposalAiDraft] System prompt not found for #{DT_PROMPT_KEY}" if prompt.nil?

      prompt
    end

    def build_user_prompt(criteria)
      criteria_list = criteria.map.with_index(1) do |c, i|
        "#{i}. [id=#{c.id}] #{c.name}\n   Instruction: #{c.ai_instruction}"
      end.join("\n")

      <<~PROMPT
        Proposal title: #{@resource.title}
        Proposal description: #{@resource.description}

        Soft criteria (score each from #{SCORE_MIN} to #{SCORE_MAX}):
        #{criteria_list}
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          total_score: {
            type: "integer",
            description: "Sum of all per-criterion scores."
          },
          overall_feedback: {
            type: "string",
            description: "Short summary feedback for the proposal as a whole."
          },
          criteria: {
            type: "array",
            description: "Per-criterion scoring with feedback.",
            items: {
              type: "object",
              properties: {
                id: { type: "integer", description: "The criterion id supplied in the prompt." },
                name: { type: "string", description: "The criterion name." },
                score: {
                  type: "integer",
                  description: "Score from #{SCORE_MIN} to #{SCORE_MAX}.",
                  minimum: SCORE_MIN,
                  maximum: SCORE_MAX
                },
                feedback: { type: "string", description: "Qualitative feedback explaining the score." }
              },
              required: ["id", "name", "score", "feedback"],
              additionalProperties: false
            }
          }
        },
        required: ["total_score", "overall_feedback", "criteria"],
        additionalProperties: false
      }
    end
end
