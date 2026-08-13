class Whatsapp::AiAssistant::DraftDecisionService < ApplicationService
  # What a citizen meant by answering the draft card, or the preview before
  # publishing, in words instead of tapping a pill. Every typed answer at those
  # steps lands here — "ja" and "passt so" the same as "ja aber der Titel ist
  # zu lang". Before it existed, anything off a fixed keyword list fell through
  # to re-sending the same card, which reads as the bot ignoring what they
  # wrote.
  #
  # The fast model, like the intent router: one short judgement on a turn the
  # citizen is already waiting through.
  REQUEST_TIMEOUT_SECONDS = 15
  DESCRIPTION_PREVIEW_LENGTH = 600

  # The three answers the two steps can act on. Anything the model returns that
  # is not one of these is read as unclear, which is the branch that re-sends the
  # card — the same thing that happened before this service existed.
  VERDICTS = %w[publish revise unclear].freeze
  UNCLEAR = :unclear

  def initialize(conversation:, inbound_text:)
    @conversation = conversation
    @inbound_text = inbound_text.to_s.strip
  end

  # Always answers, and always with something the caller can dispatch on. AI
  # switched off, no draft to judge against, an unreachable provider, a reply
  # that came back empty — all land on unclear, so a failure here costs the
  # citizen a repeated card rather than a published proposal they did not confirm
  # or a lost submission.
  def call
    return unclear if @inbound_text.blank?
    return unclear if draft_resource.blank?
    return unclear if !::Ai::Settings.ai_available?

    verdict, correction = judge

    return unclear if !VERDICTS.include?(verdict)

    ServiceResult.success(verdict: verdict.to_sym, correction: correction.presence)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] draft decision failed: #{e.class} - #{e.message}")

    unclear
  end

  private

    def draft_resource
      @conversation.draft_resource
    end

    def unclear
      ServiceResult.success(verdict: UNCLEAR, correction: nil)
    end

    def judge
      content = response_content

      [content["verdict"].to_s, content["correction"].to_s]
    end

    def response_content
      ::Ai::RubyLlmFactory
        .fast_chat(REQUEST_TIMEOUT_SECONDS)
        .with_schema(output_schema)
        .with_instructions(instructions)
        .ask(user_prompt)
        .content
        .to_h
    end

    # Publishing cannot be taken back from the chat, so the instruction is
    # deliberately lopsided: anything short of agreement is not agreement. An
    # unclear verdict costs the citizen one repeated question; a wrong publish
    # verdict costs them a public proposal they never approved.
    def instructions
      <<~TEXT
        A citizen is submitting a contribution to a participation portal over WhatsApp. They have
        been shown a draft written from their own idea and asked whether it should be submitted as
        it stands. They answered in words rather than tapping a button. Decide what they meant.

        Return one of three verdicts:
        - publish: they agree the draft should go in as it stands. Only for plain agreement —
          "ja", "passt", "passt so", "genau so", "einverstanden", "sieht gut aus".
        - revise: they want something changed, however they say it, including when they agree and
          ask for a change in the same breath ("ja, aber der Titel ist zu lang"). Also for a plain
          refusal with no reason given.
        - unclear: anything else — a question to the assistant, a new idea, small talk, or a reply
          you cannot read with confidence as one of the two above.

        When and only when the verdict is revise, also return the change they asked for, in their
        own language and as close to their own words as you can, as an instruction to whoever
        rewrites the draft ("den Titel kürzer machen"). Return null for it when they said they want
        a change but not what it should be, and never invent one they did not ask for. Never treat
        a request to change something as agreement, and when in doubt between publish and anything
        else, do not answer publish.
      TEXT
    end

    def user_prompt
      <<~PROMPT
        The draft they were shown:
        Title: "#{draft_resource.title}"
        Text: "#{description_preview}"

        What they answered:
        "#{@inbound_text}"
      PROMPT
    end

    # Flattened and cut because the model is being asked what the citizen meant,
    # not to read the whole draft: the markup and the tail of a long description
    # would be most of the tokens and none of the judgement.
    def description_preview
      ::Whatsapp.plain_text(draft_resource.description, length: DESCRIPTION_PREVIEW_LENGTH)
    end

    def output_schema
      {
        type: "object",
        properties: {
          verdict: {
            type: "string",
            enum: VERDICTS,
            description: "publish when they agree as it stands, revise when they want something " \
                         "changed, unclear otherwise."
          },
          correction: {
            type: ["string", "null"],
            description: "The change they asked for, in their own language, as an instruction to " \
                         "whoever rewrites the draft. Null unless the verdict is revise and they " \
                         "said what to change."
          }
        },
        required: %w[verdict correction],
        additionalProperties: false
      }
    end
end
