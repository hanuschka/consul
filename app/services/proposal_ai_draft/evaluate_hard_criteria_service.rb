class ProposalAiDraft::EvaluateHardCriteriaService < ApplicationService
  DT_PROMPT_KEY = :proposal_evaluate_hard_criteria

  def initialize(resource:)
    @resource = resource
  end

  def call
    criteria = @resource.projekt_phase.user_resource_criteria.hard_kind.to_a
    return empty_result if criteria.empty?

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema, feature: "proposal_ai_draft.hard_criteria")
        .with_instructions(build_system_instructions)
        .ask(build_user_prompt(criteria))

    response.content
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] EvaluateHardCriteriaService failed: #{e.class} - #{e.message}")
    Rails.logger.error("[ProposalAiDraft] Backtrace: #{e.backtrace.first(5).join("\n")}")
    raise e
  end

  private

    def empty_result
      { "all_passed" => true, "criteria" => [] }
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

        Hard criteria (all must pass; evaluate each independently):
        #{criteria_list}
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          all_passed: {
            type: "boolean",
            description: "True when every hard criterion passes."
          },
          criteria: {
            type: "array",
            description: "Per-criterion pass/fail with feedback.",
            items: {
              type: "object",
              properties: {
                id: { type: "integer", description: "The criterion id supplied in the prompt." },
                name: { type: "string", description: "The criterion name." },
                passed: { type: "boolean", description: "Whether the proposal satisfies this criterion." },
                feedback: { type: "string", description: "Actionable feedback when failed; short confirmation when passed." }
              },
              required: ["id", "name", "passed", "feedback"],
              additionalProperties: false
            }
          }
        },
        required: ["all_passed", "criteria"],
        additionalProperties: false
      }
    end
end
