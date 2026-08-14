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

  # Takes the change the citizen asked for rather than an idea, because that is
  # what it now is: the draft is edited in place from this instruction instead of
  # being written again from the original idea with the correction appended to it.
  def self.from_revision(conversation:, correction:, inbound_message_id: nil)
    new(
      conversation: conversation, idea_text: correction,
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
      conversation: conversation, idea_text: conversation.last_idea_text,
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

  # The permission re-check guards every way in — a first idea, a retry, an
  # accepted duplicate, a revision — because each can arrive minutes or days
  # after the tap that opened the flow. It sits outside the rescue below:
  # what it refuses is not a failed generation.
  def call
    return if refuse_if_not_permitted

    build
  end

  private

    def build
      return send_throttle_notice if throttled?
      return send_draft_failed if revising_without_draft?

      # Stored before the gate because the retry button reads it back, and after
      # a failed check it is the only copy of what the citizen wrote.
      store_inbound_text

      if !@screened
        # Screened before the "one moment" message rather than after it: a text
        # that is about to be refused should not first be promised a draft, and
        # the generation call it would have paid for is the one thing worth
        # skipping. The bubble covers the screening call — it is a completion
        # like any other — and an already-screened text has no call to cover,
        # so the bubble is asked for inside the gate too.
        Whatsapp::Send.typing(message_id: @inbound_message_id)

        # Armed inside the gate it guards rather than above it. Stamped
        # unconditionally, an already-screened text would record a screening that
        # never ran and re-arm the floor against the citizen's next real idea.
        @conversation.stamp_screened!

        return send_safety_check_failed if !safety.success?
        return refuse_content if safety.reason.present?
        return if duplicates_offered?
      end

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.drafting")
      )

      # After the "one moment" message, not before it: sending any message
      # dismisses the bubble, so asking for it first would spend it on the
      # millisecond before the wait rather than on the wait.
      Whatsapp::Send.typing(message_id: @inbound_message_id)

      # One write under the advisory lock: the model batches the draft, its
      # card summary, and the drafting clock (see store_generated_draft!).
      @conversation.store_generated_draft!(generate)

      complete
    rescue StandardError => e
      report(e, "draft generation")

      send_draft_failed
    end

    # A correction is stored under its own key. last_idea_text is what
    # PersistDraftService writes to the record's ai_idea_text, so a correction put
    # there would replace the citizen's original idea with "make the title
    # shorter" — and the resume recap, which reads it back, would show them that
    # instead of what they came to submit.
    def store_inbound_text
      return @conversation.store_correction!(@idea_text) if @copy == :revised

      @conversation.store_idea_text!(@idea_text)
    end

    # The card's own step cannot be reached before the record exists, but a
    # WhatsApp button stays tappable forever and the retry pill outlives the draft
    # it belonged to. A revision with nothing to revise says so here rather than
    # raising inside the edit call.
    def revising_without_draft?
      @copy == :revised && @conversation.draft_resource.blank?
    end

    def send_draft_failed
      Whatsapp::Send.recovery(
        conversation: @conversation,
        body: Whatsapp.phrase("whatsapp.bot.draft_failed"),
        actions: [:retry, :cancel]
      )
    end

    # The screening call also brings back the words the duplicate search should
    # widen itself with: both questions read the same raw text, so asking them
    # together costs one completion where two used to be paid.
    def safety
      @safety ||=
        ::ProposalAiDraft::EvaluateContentSafetyService.with_search_terms(idea_text: @idea_text)
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
        conversation: @conversation, idea_text: @idea_text,
        search_terms: safety.search_terms
      )
    end

    # Fail closed. The alternative is publishing whatever the check could not
    # read, and a submission postponed by an outage is recoverable in a way a
    # published slur is not — the retry button re-runs this whole service with
    # the text the citizen already sent.
    def send_safety_check_failed
      Whatsapp::Send.recovery(
        conversation: @conversation,
        body: Whatsapp.phrase("whatsapp.bot.safety_check_failed"),
        actions: [:retry, :cancel]
      )
    end

    # A revision edits the record that exists; a first draft writes one from
    # nothing. Both return the same complete draft_data, because
    # CompleteDraftService and PersistDraftService downstream cannot tell — and
    # must not have to tell — which of the two produced it.
    def generate
      return revise if @copy == :revised

      generate_first_draft
    end

    # Called direct rather than through a Whatsapp:: wrapper of the same name:
    # the wrapper was one delegation, and two GenerateDraftServices one namespace
    # apart is what made comments elsewhere describe the wrong one.
    #
    # The required-taxonomy entry point, because the chat has no form to fall
    # back to: the schema forces a valid category and sentiment wherever the
    # provider enforces schemas, and what a schema cannot force — a stray
    # answer from a non-strict provider, an option removed between the two
    # calls — falls to CompleteDraftService's question in the chat.
    def generate_first_draft
      ::ProposalAiDraft::GenerateDraftService.with_required_taxonomy(
        idea_text: @idea_text,
        projekt_phase: @conversation.projekt_phase
      ).to_h
    end

    def revise
      Whatsapp::AiAssistant::ReviseDraftService.call(
        resource: @conversation.draft_resource,
        correction: @idea_text,
        projekt_phase: @conversation.projekt_phase,
        card_summary: @conversation.card_summary
      )
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
      return true if within?(@conversation.last_draft_at, DRAFT_INTERVAL)

      !@screened && within?(@conversation.last_screened_at, SCREENING_INTERVAL)
    end

    def within?(stamped_at, interval)
      return false if stamped_at.blank?

      Time.zone.parse(stamped_at) > interval.ago
    end

    def send_throttle_notice
      Whatsapp::Send.recovery(
        conversation: @conversation,
        body: Whatsapp.phrase("whatsapp.bot.too_fast"),
        actions: [:cancel]
      )
    end
end
