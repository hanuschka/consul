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
        .chat_with_json_output(output_schema)
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

        #{citizen_feedback_prompt_section}
      PROMPT
    end

    # Rules for the second wording each verdict carries. The chat shows the
    # failure to someone whose contribution does not exist yet — feedback that
    # names "the proposal" reads as being about somebody else's finished thing,
    # so a version addressed to the writer rides the same completion instead of
    # being paid for separately afterwards.
    def citizen_feedback_prompt_section
      <<~TEXT
        For every criterion also return citizen_feedback: the same feedback rewritten to the
        person who wrote the idea, in the language of the proposal, addressing them
        #{::Whatsapp.address_form_instruction}. Open by naming what they asked for — "You would
        like ..." — then give the reason exactly as in your feedback, but so that it never refers
        to the proposal, the contribution or the Beitrag as an existing thing; where the reason is
        about what they wrote, make them its subject ("you do not name a specific place"). Two
        short sentences at most, no question, no advice on what to do next, nothing softened and
        nothing added. An empty string when the criterion passed.
      TEXT
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
                feedback: { type: "string", description: "Actionable feedback when failed; short confirmation when passed." },
                citizen_feedback: {
                  type: "string",
                  description: "The failed criterion's feedback rewritten to the person who " \
                               "wrote the idea, per the prompt's rules. Empty when passed."
                }
              },
              required: ["id", "name", "passed", "feedback", "citizen_feedback"],
              additionalProperties: false
            }
          }
        },
        required: ["all_passed", "criteria"],
        additionalProperties: false
      }
    end
end
