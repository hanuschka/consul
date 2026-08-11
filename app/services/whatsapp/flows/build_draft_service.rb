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

  def initialize(conversation:, idea_text:, copy: :first, inbound_message_id: nil)
    super(conversation: conversation)
    @idea_text = idea_text
    @copy = copy
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

    return send_safety_check_failed if !safety.success?
    return refuse_content if safety.reason.present?

    # Only a draft that is actually about to be generated arms the throttle.
    # Armed before the gate, a refusal answered by the rewrite its own copy
    # invites — or a failed check answered by the retry button it offers — is
    # met with "one moment, I am working on your contribution" instead, which
    # is a dead end and is not true.
    @conversation.merge_context!(last_draft_at: Time.current.iso8601)

    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp::AiAssistant::PhrasingService.call(key: "whatsapp.bot.drafting")
    )

    # After the "one moment" message, not before it: sending any message
    # dismisses the bubble, so asking for it first would spend it on the
    # millisecond before the wait rather than on the wait.
    Whatsapp::Outbound.typing(message_id: @inbound_message_id)

    @conversation.merge_context!(draft_data: generate)

    complete
  rescue StandardError => e
    report(e, "draft generation")

    Whatsapp::Outbound.recovery(
      conversation: @conversation,
      body: I18n.t("whatsapp.bot.draft_failed"),
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

    # Fail closed. The alternative is publishing whatever the check could not
    # read, and a submission postponed by an outage is recoverable in a way a
    # published slur is not — the retry button re-runs this whole service with
    # the text the citizen already sent.
    def send_safety_check_failed
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.safety_check_failed"),
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

    def throttled?
      last_draft_at = @conversation.context["last_draft_at"]

      return false if last_draft_at.blank?

      Time.zone.parse(last_draft_at) > DRAFT_INTERVAL.ago
    end

    def send_throttle_notice
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.too_fast"),
        actions: [:cancel]
      )
    end
end
