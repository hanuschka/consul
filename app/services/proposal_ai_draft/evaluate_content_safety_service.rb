class ProposalAiDraft::EvaluateContentSafetyService < ApplicationService
  # Run on what the citizen wrote, before a single token is spent turning it
  # into a proposal. The phase's own criteria are a separate question asked
  # later by EvaluateTwoTierService: those are the portal's editorial rules and
  # a draft that fails one is worth revising, whereas nothing here is.
  #
  # The verdict is a key rather than a sentence, so the reply the citizen reads
  # stays in the locale files with every other piece of bot copy and the model
  # is never the thing writing a refusal.
  REASONS = %w[
    hate
    violence
    harassment
    sexual
    illegal
    personal_data
    spam
  ].freeze

  # The enum has no null member: a nullable union is not portable across every
  # provider the factory can be pointed at, so "nothing wrong with it" is a
  # value of the same type as the rest.
  NO_REASON = "none".freeze

  def initialize(idea_text:)
    @idea_text = idea_text
  end

  # Success carries `reason`: nil when the text may be drafted, one of REASONS
  # when it may not. A failure means the question could not be asked at all,
  # which is not the same answer as "safe" and is left for the caller to decide
  # about.
  def call
    return ServiceResult.success(reason: nil) if @idea_text.blank?

    content = response_content

    return ServiceResult.success(reason: nil) if safe?(content)

    ServiceResult.success(reason: refusal_reason(content))
  rescue StandardError => e
    Rails.logger.error(
      "[ProposalAiDraft] EvaluateContentSafetyService failed: #{e.class} - #{e.message}"
    )

    ServiceResult.failure(error: e.message)
  end

  private

    def response_content
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .with_instructions(instructions)
        .ask(user_prompt)
        .content
        .to_h
    end

    # A refusal the model asks for but cannot name is still a refusal, so the
    # generic reason stands in rather than the text being let through on a
    # technicality.
    def safe?(content)
      content["safe"] == true && content["reason"].to_s == NO_REASON
    end

    def refusal_reason(content)
      reason = content["reason"].to_s

      return reason if REASONS.include?(reason)

      REASONS.first
    end

    # Deliberately narrow. The citizen is describing a problem in their
    # neighbourhood, and anger, blunt criticism of the administration and
    # unrealistic demands are all normal participation — a filter that reads
    # them as unsafe would refuse the people the portal exists for.
    def instructions
      <<~TEXT
        You screen what a citizen wrote to a participation portal before it is turned into a
        published contribution. Decide only whether publishing this text would break the law or
        the portal's content policy.

        Refuse it when it contains:
        - hate: attacks or slurs against people for who they are
        - violence: threats, or calls to harm people or property
        - harassment: abuse aimed at a named individual
        - sexual: sexual or pornographic content
        - illegal: instructions or encouragement for criminal acts, extremist propaganda
        - personal_data: someone else's private data — a full name with an address, a phone
          number, a licence plate, health details
        - spam: advertising, a scam, or text with no participation content at all

        Everything else is safe, including anger, sharp criticism of the authorities or of named
        politicians in their public role, complaints, unrealistic or expensive demands, poor
        spelling and text in any language. Political disagreement is participation, not a policy
        violation. When you are unsure, answer that it is safe.

        Answer with safe=true and reason="#{NO_REASON}", or safe=false and the single reason that
        fits best.
      TEXT
    end

    def user_prompt
      <<~PROMPT
        The citizen wrote:
        "#{@idea_text}"
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          safe: {
            type: "boolean",
            description: "True when the text may be turned into a published contribution."
          },
          reason: {
            type: "string",
            enum: REASONS + [NO_REASON],
            description: "The single policy the text breaks, or \"#{NO_REASON}\" when it is safe."
          }
        },
        required: %w[safe reason],
        additionalProperties: false
      }
    end
end
