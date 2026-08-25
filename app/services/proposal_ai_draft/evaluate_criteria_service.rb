class ProposalAiDraft::EvaluateCriteriaService < ApplicationService
  def initialize(resource:)
    @resource = resource
  end

  def call
    criteria = @resource.projekt_phase.user_resource_criteria.to_a
    system_instructions = build_system_instructions
    user_prompt = build_user_prompt(criteria)

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema, feature: "proposal_ai_draft.evaluate_criteria")
        .with_instructions(system_instructions)
        .ask(user_prompt)

    response.content
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] EvaluateCriteriaService failed: #{e.class} - #{e.message}")
    Rails.logger.error("[ProposalAiDraft] Backtrace: #{e.backtrace.first(5).join("\n")}")
    raise e
  end

  private

    def fetch_system_prompt
      parsed_response = DtApi::Client.new(use_cache: true).consul_ai_prompts.get(:proposal_evaluate_criteria).parsed_response
      parsed_response.dig("consul_ai_prompt", "prompt")
    end

    def build_system_instructions
      system_prompt = fetch_system_prompt
      raise "[ProposalAiDraft] System prompt not found for proposal_evaluate_criteria" if system_prompt.nil?

      system_prompt
    end

    def build_user_prompt(criteria)
      criteria_list = criteria.map.with_index(1) { |c, i| "#{i}. #{c.text}" }.join("\n")

      <<~PROMPT
        Proposal title: #{@resource.title}
        Proposal description: #{@resource.description}

        Criteria:
        #{criteria_list}
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          total_score: {
            type: "integer",
            description: "The sum of all individual criteria scores."
          },
          overall_passed: {
            type: "boolean",
            description: "Whether the proposal passes all required criteria overall."
          },
          overall_feedback: {
            type: "string",
            description: "A summary feedback message for the proposal as a whole."
          },
          criteria: {
            type: "array",
            description: "Evaluation results for each individual criterion.",
            items: {
              type: "object",
              properties: {
                text: {
                  type: "string",
                  description: "The exact criterion text being evaluated."
                },
                score: {
                  type: "integer",
                  description: "Score awarded for this criterion."
                },
                feedback: {
                  type: "string",
                  description: "Explanation of how well the proposal meets this criterion."
                },
                passed: {
                  type: "boolean",
                  description: "Whether the proposal meets this criterion."
                }
              },
              required: ["text", "score", "feedback", "passed"],
              additionalProperties: false
            }
          }
        },
        required: ["total_score", "overall_passed", "overall_feedback", "criteria"],
        additionalProperties: false
      }
    end
end
