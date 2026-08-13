class Whatsapp::AiAssistant::MessageIntentService < ApplicationService
  # One reading of an inbound message, ahead of every flow: does it ask to
  # leave the channel, to come back to it, or to abandon what is in progress —
  # or none of these, which is almost every message. It replaces the keyword
  # lists that used to decide the same three questions and the separate
  # per-question model calls that widened them, so a message pays one
  # completion here rather than one per question.
  #
  # None on every failure — a blank message, AI switched off, an unreachable
  # provider, a verdict outside the set. Every caller is a widening of a flow
  # that already worked without it, so the flow carrying on is the only safe
  # answer to a model that did not answer. The one exception that cannot wait
  # for a model is the typed opt-out word, and that is exactly why
  # ProcessMessageService keeps its deterministic STOP check ahead of this.
  REQUEST_TIMEOUT_SECONDS = 10

  VERDICTS = %w[opt_out opt_in abort none].freeze
  NONE = :none

  # Deliberately lopsided towards none, for the same reasons the separate
  # checks were: a missed opt-out costs one unanswered paraphrase and the
  # citizen says it again; a wrong opt-out silences a channel they wanted. A
  # missed abort costs one more message; a wrong abort throws away a
  # submission they were part-way through writing.
  INSTRUCTIONS_TEMPLATE = <<~TEXT.freeze
    A citizen writes to a participation portal's WhatsApp bot. Decide whether their message is one
    of the three channel-level requests below. Almost every message is none of them: an idea, an
    answer to whatever the bot just asked, a question, small talk.

    - opt_out: they ask to stop receiving messages from this channel altogether — unsubscribing,
      being taken off the list, wanting no further messages. Only when that reading is
      unmistakable, however they phrase it: "stop", "abmelden", "bitte keine nachrichten mehr",
      "nehmt mich von der liste", "hör auf mir zu schreiben", "please stop messaging me". A
      complaint about too many messages that does not ask for them to end is not opt_out, and
      neither is cancelling what is in progress.

    - opt_in: they ask to receive messages from this channel again after having stopped them —
      "start", "ich möchte wieder nachrichten bekommen", "nehmt mich wieder auf". Only meaningful
      while the number is unsubscribed; from a subscribed number, words like "anmelden" usually
      mean logging in or joining something, which is none.

    - abort: they want to abandon the submission or question currently in progress, however they
      phrase it: "abbrechen", "cancel", "lass mal", "vergiss es", "ach doch nicht", "ne, lieber
      nicht", "ich mach das später", "stop das". Abandoning one submission is not opt_out. Never
      abort for:
      - the answer the bot is waiting for — an idea, a correction, a description, a place
      - a refusal of one optional part rather than the whole thing — no picture, no location,
        no category
      - a question to the bot, hesitation, thinking out loud, or a complaint that is not a
        request to stop

    - none: everything else.

    Current state of this conversation:
    - %{interaction_state}
    - %{subscription_state}

    When in doubt between any request and none, answer none.
  TEXT

  INTERACTION_OPEN_STATE =
    "A submission or question is in progress, so there is something to abort.".freeze
  INTERACTION_CLOSED_STATE =
    "Nothing is in progress. There is nothing to abort, so abort is never the answer.".freeze

  OPTED_OUT_STATE =
    "The number is currently unsubscribed from the channel.".freeze
  SUBSCRIBED_STATE =
    "The number is currently subscribed, so opt_in is never the answer.".freeze

  def initialize(inbound_text:, interaction_open:, opted_out:)
    @inbound_text = inbound_text.to_s.strip
    @interaction_open = interaction_open
    @opted_out = opted_out
  end

  def call
    return NONE if @inbound_text.blank?
    return NONE if !::Ai::Settings.ai_available?

    verdict = classified_intent

    return NONE if !VERDICTS.include?(verdict)

    verdict.to_sym
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] message intent failed: #{e.class} - #{e.message}")

    NONE
  end

  private

    def classified_intent
      ::Ai::RubyLlmFactory
        .fast_chat(REQUEST_TIMEOUT_SECONDS)
        .with_schema(output_schema)
        .with_instructions(instructions)
        .ask(@inbound_text)
        .content
        .to_h["intent"]
        .to_s
    end

    # The state lines are what let one prompt answer for every step: the model
    # is told outright when there is nothing to abort and when opt_in cannot
    # apply, instead of being left to guess the conversation's shape from a
    # bare message. The caller gates on the same facts again — a verdict the
    # state rules out is dropped, not acted on.
    def instructions
      sprintf(
        INSTRUCTIONS_TEMPLATE,
        interaction_state: @interaction_open ? INTERACTION_OPEN_STATE : INTERACTION_CLOSED_STATE,
        subscription_state: @opted_out ? OPTED_OUT_STATE : SUBSCRIBED_STATE
      )
    end

    def output_schema
      {
        type: "object",
        properties: {
          intent: {
            type: "string",
            enum: VERDICTS,
            description: "opt_out when they unmistakably ask to stop receiving messages " \
                         "altogether, opt_in when they ask to receive them again, abort when " \
                         "they abandon the submission in progress, none otherwise."
          }
        },
        required: ["intent"],
        additionalProperties: false
      }
    end
end
