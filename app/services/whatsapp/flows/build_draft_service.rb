class Whatsapp::Flows::BuildDraftService < Whatsapp::Flows::BaseService
  # Everything between "the citizen sent an idea" and "the draft card is on
  # screen": the rate guard and the generation call. What happens to the result
  # — asking for a missing choice, writing the record, showing the card — is
  # CompleteDraftService's, because a category answer arriving a message later
  # has to reach exactly the same decision.
  #
  # Revisions are unlimited by design, so the abuse guard is a rate limit per
  # conversation rather than a cap on rounds.
  DRAFT_INTERVAL = 15.seconds

  # The screening call is throttled separately and far more loosely. It has to
  # be throttled at all — a refused text is invited to be rewritten and a
  # failed check offers a retry button, so without a floor the refusal loop is
  # an unbounded completion-per-message hole that never reaches a draft. But it
  # cannot share the drafting floor: fifteen seconds would answer the rewrite
  # its own copy just asked for with "one moment, I am working on your
  # contribution", which is both a dead end and untrue.
  SCREENING_INTERVAL = 3.seconds

  # Two entry points rather than one with a flag: the only thing that differs is
  # which copy the finished card carries, and a caller reading
  # `BuildDraftService.call(..., true)` could not tell you which.
  def self.from_idea(conversation:, idea_text:, inbound_message_id: nil)
    new(
      conversation: conversation, idea_text: idea_text,
      copy: :first, inbound_message_id: inbound_message_id
    ).call
  end

  def self.from_revision(conversation:, idea_text:, inbound_message_id: nil)
    new(
      conversation: conversation, idea_text: idea_text,
      copy: :revised, inbound_message_id: inbound_message_id
    ).call
  end

  # The same first draft, for a text that has already been through the gates
  # and that the citizen chose to submit anyway after being shown what the
  # phase already holds. Screening it a second time would buy the identical
  # answer, and inside the screening floor it would answer their tap with "one
  # moment, you are too fast".
  #
  # The text is read from the conversation rather than passed in: the caller
  # answers a tapped pill, which carries one short parameter and not a
  # paragraph, so it would only be reading the same key back out to hand it
  # over — and this service is where that key is written in the first place.
  def self.from_accepted_idea(conversation:, inbound_message_id: nil)
    new(
      conversation: conversation, idea_text: conversation.context["last_idea_text"],
      copy: :first, screened: true, inbound_message_id: inbound_message_id
    ).call
  end

  def initialize(conversation:, idea_text:, copy: :first, screened: false, inbound_message_id: nil)
    super(conversation: conversation)
    @idea_text = idea_text
    @copy = copy
    @screened = screened
    @inbound_message_id = inbound_message_id
  end

  def call
    return send_throttle_notice if throttled?

    # Stored before the gate because the retry button reads it back, and after
    # a failed check it is the only copy of what the citizen wrote.
    @conversation.merge_context!(last_idea_text: @idea_text)

    # Screened before the "one moment" message rather than after it: a text
    # that is about to be refused should not first be promised a draft, and the
    # generation call it would have paid for is the one thing worth skipping.
    # The bubble covers this call too — it is a completion like any other.
    Whatsapp::Outbound.typing(message_id: @inbound_message_id)

    if !@screened
      # Armed inside the gate it guards rather than above it. Stamped
      # unconditionally, an already-screened text would record a screening that
      # never ran and re-arm the floor against the citizen's next real idea.
      @conversation.merge_context!(last_screened_at: Time.current.iso8601)

      return send_safety_check_failed if !safety.success?
      return refuse_content if safety.reason.present?
      return if duplicates_offered?
    end

    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.drafting")
    )

    # After the "one moment" message, not before it: sending any message
    # dismisses the bubble, so asking for it first would spend it on the
    # millisecond before the wait rather than on the wait.
    Whatsapp::Outbound.typing(message_id: @inbound_message_id)

    # The drafting clock is armed in the same write as the result rather than
    # in one of its own: the advisory lock means no other message can read it
    # while `generate` runs, so a second write beforehand buys nothing.
    @conversation.merge_context!(draft_data: generate, last_draft_at: Time.current.iso8601)

    complete
  rescue StandardError => e
    report(e, "draft generation")

    Whatsapp::Outbound.recovery(
      conversation: @conversation,
      body: Whatsapp.phrase("whatsapp.bot.draft_failed"),
      actions: [:retry, :cancel]
    )
  end

  private

    def safety
      @safety ||= ::ProposalAiDraft::EvaluateContentSafetyService.call(idea_text: @idea_text)
    end

    def refuse_content
      Whatsapp::Flows::RefuseContentService.call(
        conversation: @conversation, reason: safety.reason
      )
    end

    # Asked after screening and before generation, which is the only point
    # where it is both safe and still free: a text about to be refused should
    # not first be shown what it duplicates, and a generated draft is the cost
    # the question exists to avoid.
    #
    # Only on a first idea. A revision refines something already checked, and
    # re-asking every round would stand between the citizen and the change they
    # came back to make. Returns true when it took the turn over.
    def duplicates_offered?
      return false if @copy != :first

      Whatsapp::Flows::AskDuplicateChoiceService.for_idea(
        conversation: @conversation, idea_text: @idea_text
      )
    end

    # Fail closed. The alternative is publishing whatever the check could not
    # read, and a submission postponed by an outage is recoverable in a way a
    # published slur is not — the retry button re-runs this whole service with
    # the text the citizen already sent.
    def send_safety_check_failed
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: Whatsapp.phrase("whatsapp.bot.safety_check_failed"),
        actions: [:retry, :cancel]
      )
    end

    # Called direct rather than through a Whatsapp:: wrapper of the same name:
    # the wrapper was one delegation, and two GenerateDraftServices one namespace
    # apart is what made comments elsewhere describe the wrong one.
    def generate
      ::ProposalAiDraft::GenerateDraftService.call(
        idea_text: @idea_text,
        projekt_phase: @conversation.projekt_phase
      ).to_h
    end

    def complete
      return Whatsapp::Flows::CompleteDraftService.for_revised_draft(
        conversation: @conversation, inbound_message_id: @inbound_message_id
      ) if @copy == :revised

      Whatsapp::Flows::CompleteDraftService.for_first_draft(
        conversation: @conversation, inbound_message_id: @inbound_message_id
      )
    end

    # Two clocks, because the two calls this service makes cost differently and
    # are reached differently: a draft is the expensive one and is followed by
    # a card to read, a screening is the cheap one and may be followed straight
    # away by the rewrite its refusal asked for.
    #
    # Each clock guards the call it belongs to, so the screening floor is read
    # only when a screening is going to happen. Read unconditionally it would
    # refuse the tap that answered the duplicate offer, moments after the turn
    # that offered it stamped the clock.
    def throttled?
      return true if within?("last_draft_at", DRAFT_INTERVAL)

      !@screened && within?("last_screened_at", SCREENING_INTERVAL)
    end

    def within?(context_key, interval)
      stamped_at = @conversation.context[context_key]

      return false if stamped_at.blank?

      Time.zone.parse(stamped_at) > interval.ago
    end

    def send_throttle_notice
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: Whatsapp.phrase("whatsapp.bot.too_fast"),
        actions: [:cancel]
      )
    end
end
