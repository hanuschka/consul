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

    def build_prompt(criteria)
      criteria_list = criteria.map.with_index(1) { |c, i| "#{i}. #{c.text}" }.join("\n")
      <<~PROMPT
        Evaluate the following proposal against the given criteria. Score each criterion from 0 to 25.

        Proposal title: #{@resource.title}
        Proposal description: #{@resource.description}

        Criteria:
        #{criteria_list}

        For each criterion provide: the criterion text, a score (0-25), a one-sentence feedback, and whether it passed (score >= 15).
        Also provide a total_score (sum of all criteria scores) and an overall assessment.

        Respond in the same language as the proposal.
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          total_score:      { type: "integer" },
          overall_passed:   { type: "boolean" },
          overall_feedback: { type: "string" },
          criteria: {
            type: "array",
            items: {
              type: "object",
              properties: {
                text:      { type: "string" },
                score:     { type: "integer" },
                feedback:  { type: "string" },
                passed:    { type: "boolean" }
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
