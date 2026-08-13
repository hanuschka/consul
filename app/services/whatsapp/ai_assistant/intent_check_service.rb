class Whatsapp::AiAssistant::IntentCheckService < ApplicationService
  # One yes-or-no reading of an inbound message. The skip checks sit on it —
  # did they decline the picture, did they decline the pin — each the same
  # call: a short judgement on a message at the step that asked the question.
  #
  # They share this because they must share one failure contract. Every caller
  # is a widening of something that already worked without it, so false is the
  # only safe answer to a provider that did not respond, and one copy drifting
  # into returning true on error is the failure nobody would see until a
  # citizen's photo or pin was skipped by a timeout.
  #
  # Composed rather than inherited from: the callers hold their own prompts,
  # which is the whole of what makes them different, and pass them in.
  REQUEST_TIMEOUT_SECONDS = 10

  # The schema's one property. Named the same for every question so the readers
  # never have to agree on a key; what the question actually is reaches the model
  # through `question` and the instructions.
  ANSWER_PROPERTY = "answer".freeze

  # `question` is the property description the model reads — one sentence saying
  # what a true means here. `label` names the check in the log line, and nowhere
  # else.
  def initialize(inbound_text:, instructions:, question:, label:)
    @inbound_text = inbound_text.to_s.strip
    @instructions = instructions
    @question = question
    @label = label
  end

  def call
    return false if @inbound_text.blank?
    return false if !::Ai::Settings.ai_available?

    answered_yes?
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] #{@label} failed: #{e.class} - #{e.message}")

    false
  end

  private

    # Compared against true rather than read for truthiness: a provider that
    # answers with the string "false", or with nothing at all, must not be read
    # as agreement.
    def answered_yes?
      ::Ai::RubyLlmFactory
        .fast_chat(REQUEST_TIMEOUT_SECONDS)
        .with_schema(output_schema)
        .with_instructions(@instructions)
        .ask(@inbound_text)
        .content
        .to_h[ANSWER_PROPERTY] == true
    end

    def output_schema
      {
        type: "object",
        properties: {
          ANSWER_PROPERTY => { type: "boolean", description: @question }
        },
        required: [ANSWER_PROPERTY],
        additionalProperties: false
      }
    end
end
