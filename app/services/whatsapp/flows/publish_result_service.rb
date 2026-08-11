class Whatsapp::Flows::PublishResultService < Whatsapp::Flows::BaseService
  # Catalog C19. Three outcomes, decided by the phase's own moderation setting
  # rather than by anything the bot knows: published with its link, held for
  # review, or refused because the phase's hard criteria rejected it.
  #
  # Lifted out of Inbound::ProcessMessageService so the gate chain stays a
  # dispatcher and the thing that decides what a citizen is told about their
  # submission lives in one readable place.
  def initialize(conversation:, inbound_message_id: nil)
    super(conversation: conversation)
    @inbound_message_id = inbound_message_id
  end

  def call
    # Usually instant now that the draft card carries the evaluation, but not
    # always: a draft whose evaluation was unreachable at the time is evaluated
    # here instead, and that is a second LLM call.
    Whatsapp::Outbound.typing(message_id: @inbound_message_id)

    result = Whatsapp::Drafting::PublishDraftService.call(conversation: @conversation)

    return Whatsapp::Flows::CriteriaFeedbackService.call(conversation: @conversation) if
      result == :criteria_failed
    return Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation: @conversation) if
      result == :sentiment_missing
    return Whatsapp::Flows::AskDraftChoiceService.category(conversation: @conversation) if
      result == :category_missing
    return send_invalid if result == :invalid
    return send_failure if result.blank?

    send_confirmation(result)

    @conversation.complete_flow!

    send_next_actions
  end

  private

    # Sent after the flow is completed, so the menu is offered from a
    # conversation with nothing open in it: all three of its buttons start
    # something new, and one of them starts another submission. A guest
    # submitter is left with the confirmation alone, which the menu decides.
    def send_next_actions
      Whatsapp::Flows::MainMenuService.after_publishing(conversation: @conversation)
    end

    # Only proposals can be held back for moderation — an investment has no
    # admin_accepted column, and the web budget flow publishes it outright.
    def send_confirmation(resource)
      return send_pending(resource) if resource.is_a?(Proposal) && !resource.admin_accepted?

      Whatsapp::Outbound.text(
        account: account,
        body: I18n.t(
          "whatsapp.bot.proposal.published",
          url: Whatsapp::PublishedResourceUrl.call(resource)
        )
      )
    end

    # The link is back, and now leads somewhere: the author may open their own
    # proposal while it waits for moderation. It asks them to log in first,
    # which the copy says rather than leaving them to discover it.
    def send_pending(resource)
      Whatsapp::Outbound.text(
        account: account,
        body: I18n.t(
          "whatsapp.bot.proposal.published_pending_moderation",
          url: Whatsapp::PublishedResourceUrl.call(resource)
        )
      )
    end

    def send_failure
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.publish_failed"),
        actions: [:retry, :cancel]
      )
    end

    # The draft breaks a rule the portal applies to every submission — a title
    # too long, a description the sanitiser rejected. The citizen is put back in
    # the revision step with the record's own message, because they are the only
    # one who can rewrite it and a retry would fail identically.
    def send_invalid
      @conversation.update!(step: "awaiting_revision")

      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.draft_invalid", reason: validation_reason),
        actions: [:cancel]
      )
    end

    # Read off the record rather than re-validated: the failed save left them
    # there, and validating again would re-run the sanitiser over the whole
    # description for a message that is already available.
    def validation_reason
      @conversation.draft_resource.errors.full_messages.first.to_s
    end
end
