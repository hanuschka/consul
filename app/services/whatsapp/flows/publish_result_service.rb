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
    return if refuse_if_not_permitted

    # Usually instant now that the draft card carries the evaluation, but not
    # always: a draft whose evaluation was unreachable at the time is evaluated
    # here instead, and that is a second LLM call.
    Whatsapp::Send.typing(message_id: @inbound_message_id)

    result = Whatsapp::Drafting::PublishDraftService.call(conversation: @conversation)

    return Whatsapp::Flows::CriteriaFeedbackService.call(conversation: @conversation) if
      result == :criteria_failed
    return repair_taxonomy(:sentiment) if result == :sentiment_missing
    return repair_taxonomy(:category) if result == :category_missing
    return send_invalid if result == :invalid
    return send_failure if result.blank?

    send_confirmation(result)

    @conversation.complete_flow!

    send_next_actions
  end

  private

    # A choice went missing between creation and here — an option deleted from
    # the phase mid-flow, or a draft predating the completion gate. The marker
    # tells AskDraftChoiceService that the citizen has already confirmed the
    # preview, so their answer resumes this publish instead of rewinding them
    # to the draft card.
    def repair_taxonomy(kind)
      @conversation.mark_publish_repair!

      return Whatsapp::Flows::AskDraftChoiceService.category(conversation: @conversation) if
        kind == :category

      Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation: @conversation)
    end

    # Sent after the flow is completed, so the menu is offered from a
    # conversation with nothing open in it: all three of its buttons start
    # something new, and one of them starts another submission. A guest
    # submitter is left with the confirmation alone, which the menu decides.
    def send_next_actions
      Whatsapp::Flows::MainMenuService.follow_up(conversation: @conversation)
    end

    # Only proposals can be held back for moderation — an investment has no
    # admin_accepted column, and the web budget flow publishes it outright.
    def send_confirmation(resource)
      return send_pending(resource) if resource.is_a?(Proposal) && !resource.admin_accepted?

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase(
          "whatsapp.bot.proposal.published", url: Whatsapp::PublishedResourceUrl.call(resource)
        )
      )
    end

    # The link is back, and now leads somewhere: the author may open their own
    # proposal while it waits for moderation. It asks them to log in first,
    # which the copy says rather than leaving them to discover it.
    def send_pending(resource)
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase(
          "whatsapp.bot.proposal.published_pending_moderation",
          url: Whatsapp::PublishedResourceUrl.call(resource)
        )
      )
    end

    def send_failure
      Whatsapp::Send.recovery(
        conversation: @conversation,
        body: Whatsapp.phrase("whatsapp.bot.publish_failed"),
        actions: [:retry, :cancel]
      )
    end

    # The draft breaks a rule the portal applies to every submission — a title
    # too long, a description the sanitiser rejected. The citizen is put back in
    # the revision step with the record's own message, because they are the only
    # one who can rewrite it and a retry would fail identically.
    #
    # The same pair a failed criterion offers: both say "this cannot go in as it
    # stands", and a citizen who met one and then the other would otherwise find
    # the way out in a different place each time.
    def send_invalid
      @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_REVISION)

      Whatsapp::Send.question(
        conversation: @conversation,
        body: Whatsapp.phrase("whatsapp.bot.draft_invalid", reason: validation_reason),
        buttons: Whatsapp::FlowActions.revise_decision_buttons
      )
    end

    # Read off the record rather than re-validated: the failed save left them
    # there, and validating again would re-run the sanitiser over the whole
    # description for a message that is already available.
    def validation_reason
      @conversation.draft_resource.errors.full_messages.first.to_s
    end
end
