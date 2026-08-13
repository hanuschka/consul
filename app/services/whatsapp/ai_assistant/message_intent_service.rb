class Whatsapp::AiAssistant::MessageIntentService < ApplicationService
  # The one model reading a message gets when the router does not serve its
  # sender: guests and unlinked numbers, whose whole path is the deterministic
  # flow, and numbers that opted out, whose only open question is whether they
  # are opting back in. Linked, subscribed citizens never come here — their one
  # reading is the router's, which carries the same decisions as tools.
  #
  # One call answers everything at once: the channel-level requests (leaving
  # the channel, abandoning what is in progress) and what the message does to
  # the step it lands on (approving a draft, asking for a change, declining
  # the optional photo or pin). The verdict set is assembled from the
  # conversation's state, so the model is never offered a reading the moment
  # cannot carry.
  #
  # Answer on every failure — a blank message, AI switched off, an unreachable
  # provider, a verdict outside the set. Every verdict is a widening of a flow
  # that already worked without it, so the flow carrying on is the only safe
  # reply from a model that did not answer. The one exception that cannot wait
  # for a model is the typed opt-out word, and that is exactly why
  # ProcessMessageService keeps its deterministic STOP check ahead of this.
  REQUEST_TIMEOUT_SECONDS = 10

  ANSWER = :answer
  DESCRIPTION_PREVIEW_LENGTH = 600

  INTRO = <<~TEXT.freeze
    A citizen writes to a participation portal's WhatsApp bot. Decide what their message asks
    for, from the readings listed below. Almost every message is answer: an idea, a reply to
    whatever the bot just asked, a question, small talk.
  TEXT

  # Deliberately lopsided towards answer, reading by reading: a missed opt-out
  # costs one unanswered paraphrase and the citizen says it again; a wrong one
  # silences a channel they wanted. A missed abort or skip costs one more
  # message; a wrong abort throws away a submission they were part-way through
  # writing, and a wrong publish makes public a draft nobody approved.
  OPT_OUT_GUIDANCE = <<~TEXT.freeze
    - opt_out: they ask to stop receiving messages from this channel altogether — unsubscribing,
      being taken off the list, wanting no further messages. Only when that reading is
      unmistakable, however they phrase it: "bitte keine nachrichten mehr", "nehmt mich von der
      liste", "hör auf mir zu schreiben", "please stop messaging me". A complaint about too many
      messages that does not ask for them to end is not opt_out, and neither is cancelling what
      is in progress.
  TEXT

  OPT_IN_GUIDANCE = <<~TEXT.freeze
    - opt_in: they ask to receive messages from this channel again after having stopped them —
      "start", "ich möchte wieder nachrichten bekommen", "nehmt mich wieder auf". Only when that
      reading is unmistakable.
  TEXT

  ABORT_GUIDANCE = <<~TEXT.freeze
    - abort: they want to abandon the submission or question currently in progress, however they
      phrase it: "abbrechen", "cancel", "lass mal", "vergiss es", "ach doch nicht", "ne, lieber
      nicht", "ich mach das später", "stop das". Abandoning one submission is not opt_out. Never
      abort for the answer the bot is waiting for, for a refusal of one optional part rather
      than the whole thing — no picture, no location, no category — or for a question,
      hesitation or complaint that is not a request to stop.
  TEXT

  DRAFT_DECISION_GUIDANCE = <<~TEXT.freeze
    - publish: they agree the draft they were shown should go in as it stands. Only for plain
      agreement — "ja", "passt", "passt so", "genau so", "einverstanden", "sieht gut aus".
      Publishing cannot be taken back: never treat a request to change something as agreement,
      and when in doubt between publish and anything else, do not answer publish.

    - revise: they want something changed, however they say it, including when they agree and
      ask for a change in the same breath ("ja, aber der Titel ist zu lang"). Also for a plain
      refusal with no reason given. When and only when the verdict is revise, also return the
      change they asked for as correction, in their own language and as close to their own
      words as you can, as an instruction to whoever rewrites the draft ("den Titel kürzer
      machen"). Return null for it when they said they want a change but not what it should
      be, and never invent one they did not ask for.
  TEXT

  # The step already asked "what should I change?", so the whole message is
  # the answer and publish is the one narrower question left: did they change
  # their mind and want the draft as it stands after all.
  REVISION_GUIDANCE = <<~TEXT.freeze
    - publish: the bot has just asked them what should be changed, and their reply means they
      changed their mind and want the draft as it stands after all — "doch egal, passt so",
      "ach, lass es wie es ist". Anything that names a change, however vaguely, is answer.
  TEXT

  IMAGE_SKIP_GUIDANCE = <<~TEXT.freeze
    - skip: the bot has asked them for an optional photo and they do not want to send one,
      however they phrase it: "kein foto", "ich hab kein bild", "ohne bild", "überspringen",
      "hab grad keins", "brauch ich nicht", "weiter ohne". Not for a description of a photo
      they are about to send, or a question about what kind of picture is wanted.
  TEXT

  LOCATION_SKIP_GUIDANCE = <<~TEXT.freeze
    - skip: the bot has asked them to share an optional location pin and they do not want to or
      cannot give one: "keine adresse", "weiß ich nicht", "ist mir egal", "ohne ort",
      "überspringen", "geht auch so". A message that names a place in words rather than
      declining one ("Hauptstraße 14", "am Bahnhof", "im Stadtpark") is an answer to the
      question and not a refusal of it — that is answer.
  TEXT

  CLOSING = <<~TEXT.freeze
    - answer: everything else.

    When in doubt between any reading and answer, answer.
  TEXT

  def initialize(conversation:, inbound_text:, interaction_open:)
    @conversation = conversation
    @inbound_text = inbound_text.to_s.strip
    @interaction_open = interaction_open
  end

  def call
    return answer if @inbound_text.blank?
    return answer if !::Ai::Settings.ai_available?

    verdict, correction = judge

    return answer if !verdicts.include?(verdict)

    ServiceResult.success(verdict: verdict.to_sym, correction: correction.presence)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] message intent failed: #{e.class} - #{e.message}")

    answer
  end

  private

    def answer
      ServiceResult.success(verdict: ANSWER, correction: nil)
    end

    def opted_out?
      @conversation.whatsapp_account.opt_out_at.present?
    end

    # An unsubscribed number has exactly one live question; everyone else gets
    # the channel requests plus whatever the current step can carry. abort is
    # only offered while something is open — without that, "vergiss es" at a
    # fresh start would be read as cancelling nothing.
    def verdicts
      return %w[opt_in answer] if opted_out?

      ["opt_out", (%w[abort] if @interaction_open), step_verdicts, "answer"].flatten.compact
    end

    def step_verdicts
      steps = Whatsapp::Conversation::Step

      case @conversation.step
      when steps::AWAITING_DRAFT_DECISION, steps::AWAITING_FINAL_CONFIRMATION
        %w[publish revise]
      when steps::AWAITING_REVISION then %w[publish]
      when steps::AWAITING_IMAGE_CHOICE, steps::AWAITING_IMAGE_UPLOAD then %w[skip]
      when steps::AWAITING_LOCATION then %w[skip]
      else []
      end
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
        .ask(@inbound_text)
        .content
        .to_h
    end

    # Built from the same list the verdict is checked against, so the model is
    # never taught a reading the caller would refuse.
    def instructions
      [INTRO, *guidance_sections, draft_context, CLOSING].compact.join("\n")
    end

    def guidance_sections
      verdicts.filter_map do |verdict|
        case verdict
        when "opt_out" then OPT_OUT_GUIDANCE
        when "opt_in" then OPT_IN_GUIDANCE
        when "abort" then ABORT_GUIDANCE
        when "publish", "revise" then publish_guidance
        when "skip" then skip_guidance
        end
      end.uniq
    end

    def publish_guidance
      return REVISION_GUIDANCE if @conversation.awaiting_revision?

      DRAFT_DECISION_GUIDANCE
    end

    def skip_guidance
      return LOCATION_SKIP_GUIDANCE if @conversation.awaiting_location?

      IMAGE_SKIP_GUIDANCE
    end

    # What the publish/revise reading is judged against. Flattened and cut
    # because the model is deciding what the citizen meant, not re-reading the
    # whole draft.
    def draft_context
      return if !verdicts.include?("publish")

      draft = @conversation.draft_resource

      return if draft.blank?

      <<~TEXT
        The draft they were shown:
        Title: "#{draft.title}"
        Text: "#{::Whatsapp.plain_text(draft.description, length: DESCRIPTION_PREVIEW_LENGTH)}"
      TEXT
    end

    def output_schema
      {
        type: "object",
        properties: {
          verdict: {
            type: "string",
            enum: verdicts,
            description: "The one reading of the message, from the listed set. answer when " \
                         "unsure."
          },
          correction: {
            type: ["string", "null"],
            description: "The change they asked for, in their own language, as an instruction " \
                         "to whoever rewrites the draft. Null unless the verdict is revise and " \
                         "they said what to change."
          }
        },
        required: %w[verdict correction],
        additionalProperties: false
      }
    end
end
