class ProposalAiDraft::EvaluateTwoTierService < ApplicationService
  RESULT_VERSION = 2

  STAGE_HARD_FAILED = "hard_failed".freeze
  STAGE_COMPLETED = "completed".freeze
  STAGE_ERROR = "error".freeze

  HARD_PROMPT_KEY = :proposal_evaluate_hard_criteria
  SOFT_PROMPT_KEY = :proposal_evaluate_soft_criteria

  SCORE_MIN = 0
  SCORE_MAX = 25

  # Both tiers ride one completion: the two stage services this replaces read
  # the same title and description twice, and the soft half was paid on every
  # draft and every revision round whenever the hard half passed — the common
  # case. The two DT prompts stay separate and admin-editable; they are joined
  # below, so a phase with only one kind of criteria is prompted exactly as
  # before.
  BRIDGING_PREAMBLE = <<~TEXT.freeze
    The proposal is evaluated against two kinds of criteria in a single pass: hard criteria
    (strict pass/fail requirements) and soft criteria (scored). Apply the two sets of rules
    below independently — a hard failure does not change how the soft criteria are scored,
    and a high score does not soften a hard verdict.
  TEXT

  def initialize(resource:)
    @resource = resource
  end

  def call
    result = orchestrate
    persist(result)
    result
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] EvaluateTwoTierService failed: #{e.class} - #{e.message}")
    error_result = build_error_result(e)
    persist(error_result)
    error_result
  end

  private

    def orchestrate
      response = evaluation_response
      hard_result = response["hard"] || empty_hard_result

      if hard_failed?(hard_result)
        return hard_fail_result(hard_result)
      end

      completed_result(hard_result, soft_result_from(response))
    end

    def evaluation_response
      return {} if hard_criteria.empty? && soft_criteria.empty?

      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .with_instructions(build_system_instructions)
        .ask(build_user_prompt)
        .content
    end

    def hard_criteria
      @hard_criteria ||= @resource.projekt_phase.user_resource_criteria.hard_kind.to_a
    end

    def soft_criteria
      @soft_criteria ||= @resource.projekt_phase.user_resource_criteria.soft_kind.to_a
    end

    def empty_hard_result
      { "all_passed" => true, "criteria" => [] }
    end

    def empty_soft_result
      { "total_score" => 0, "overall_feedback" => "", "criteria" => [] }
    end

    # The total is summed here rather than trusted from the model: it is a sum
    # of numbers the same reply already carries, and a mis-added one would be
    # shown to the citizen next to the per-criterion scores it contradicts.
    def soft_result_from(response)
      soft = response["soft"]

      return empty_soft_result if soft.blank?

      soft.merge("total_score" => soft["criteria"].to_a.sum { |criterion| criterion["score"].to_i })
    end

    def hard_failed?(hard_result)
      hard_result["all_passed"] == false
    end

    def first_failing_criterion(hard_result)
      failing_ids = hard_result["criteria"].reject { |c| c["passed"] }.map { |c| c["id"] }

      return nil if failing_ids.empty?

      hard_criteria.find { |criterion| failing_ids.include?(criterion.id) }
    end

    # soft stays nil on a hard failure even though the merged call scored it:
    # every consumer of the stored result treats a present soft half as "this
    # draft completed evaluation", and a score shown next to "your draft was
    # rejected" reads as a verdict it is not.
    def hard_fail_result(hard_result)
      first_failing_criterion_record = first_failing_criterion(hard_result)
      failing_feedback = hard_result["criteria"].find { |c| c["id"] == first_failing_criterion_record&.id }

      {
        "version" => RESULT_VERSION,
        "stage" => STAGE_HARD_FAILED,
        "failed_criterion" => {
          "id" => first_failing_criterion_record&.id,
          "name" => first_failing_criterion_record&.name,
          "description" => first_failing_criterion_record&.description,
          "feedback" => failing_feedback&.dig("feedback").to_s,
          "citizen_feedback" => failing_feedback&.dig("citizen_feedback").to_s
        },
        "hard" => hard_result,
        "soft" => nil
      }
    end

    def completed_result(hard_result, soft_result)
      {
        "version" => RESULT_VERSION,
        "stage" => STAGE_COMPLETED,
        "failed_criterion" => nil,
        "hard" => hard_result,
        "soft" => soft_result,
        "total_score" => soft_result["total_score"],
        "overall_feedback" => soft_result["overall_feedback"]
      }
    end

    def build_error_result(error)
      {
        "version" => RESULT_VERSION,
        "stage" => STAGE_ERROR,
        "error_class" => error.class.name,
        "error_message" => error.message
      }
    end

    def persist(result)
      return if @resource.blank?

      @resource.update_columns(
        ai_evaluation_result: result,
        updated_at: Time.current
      )
    end

    def fetch_system_prompt(prompt_key)
      parsed = DtApi::Client.new(use_cache: true).consul_ai_prompts.get(prompt_key).parsed_response
      prompt = parsed.dig("consul_ai_prompt", "prompt")

      raise "[ProposalAiDraft] System prompt not found for #{prompt_key}" if prompt.nil?

      prompt
    end

    def build_system_instructions
      sections = []
      sections << fetch_system_prompt(HARD_PROMPT_KEY) if hard_criteria.any?
      sections << fetch_system_prompt(SOFT_PROMPT_KEY) if soft_criteria.any?

      if sections.size > 1
        sections.unshift(BRIDGING_PREAMBLE)
      end

      sections.join("\n\n")
    end

    def build_user_prompt
      <<~PROMPT
        Proposal title: #{@resource.title}
        Proposal description: #{@resource.description}

        #{[hard_prompt_section, soft_prompt_section].compact.join("\n\n")}
      PROMPT
    end

    def hard_prompt_section
      return if hard_criteria.empty?

      <<~TEXT
        Hard criteria (all must pass; evaluate each independently):
        #{criteria_list(hard_criteria)}

        #{citizen_feedback_prompt_section}
      TEXT
    end

    def soft_prompt_section
      return if soft_criteria.empty?

      <<~TEXT
        Soft criteria (score each from #{SCORE_MIN} to #{SCORE_MAX}):
        #{criteria_list(soft_criteria)}
      TEXT
    end

    def criteria_list(criteria)
      criteria.map.with_index(1) do |c, i|
        "#{i}. [id=#{c.id}] #{c.name}\n   Instruction: #{c.ai_instruction}"
      end.join("\n")
    end

    # Rules for the second wording each hard verdict carries. The chat shows the
    # failure to someone whose contribution does not exist yet — feedback that
    # names "the proposal" reads as being about somebody else's finished thing,
    # so a version addressed to the writer rides the same completion instead of
    # being paid for separately afterwards.
    def citizen_feedback_prompt_section
      <<~TEXT
        For every hard criterion also return citizen_feedback: the same feedback rewritten to the
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
      properties = {}
      properties[:hard] = hard_output_schema if hard_criteria.any?
      properties[:soft] = soft_output_schema if soft_criteria.any?

      {
        type: "object",
        properties: properties,
        required: properties.keys.map(&:to_s),
        additionalProperties: false
      }
    end

    def hard_output_schema
      {
        type: "object",
        description: "The hard-criteria verdicts.",
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

    def soft_output_schema
      {
        type: "object",
        description: "The soft-criteria scoring.",
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
