class ProposalAiDraft::EvaluateCriteriaService < ApplicationService
  def initialize(resource:)
    @resource = resource
  end

  def call
    criteria = @resource.projekt_phase.proposal_criteria.to_a
    prompt = build_prompt(criteria)
    response = Ai::RubyLlmFactory.chat_with_json_output(output_schema).ask(prompt)
    response.content
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] EvaluateCriteriaService failed: #{e.class} - #{e.message}")
    Rails.logger.error("[ProposalAiDraft] Backtrace: #{e.backtrace.first(5).join("\n")}")
    raise e
  end

  private

    def fetch_system_prompt
      cache_key = "dt_api/consul_ai_prompts/proposal_evaluate_criteria"
      parsed_response = DtApi::Caching.get_with_cache(cache_key) do
        DtApi::Client.new.consul_ai_prompts.get(:proposal_evaluate_criteria)
      end
      parsed_response.dig("consul_ai_prompt", "prompt")
    end

    def build_prompt(criteria)
      system_prompt = fetch_system_prompt
      raise "[ProposalAiDraft] System prompt not found for proposal_evaluate_criteria" if system_prompt.nil?

      criteria_list = criteria.map.with_index(1) { |c, i| "#{i}. #{c.text}" }.join("\n")
      dynamic_context = <<~CONTEXT
        Proposal title: #{@resource.title}
        Proposal description: #{@resource.description}

        Criteria:
        #{criteria_list}
      CONTEXT

      system_prompt + "\n" + dynamic_context
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
