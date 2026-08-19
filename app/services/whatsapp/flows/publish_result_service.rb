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

    # The consent gate again, because AskIdeaService's does not cover a
    # submission that was already past the idea step when the question was
    # introduced: ResumeOrRestartService#resume goes straight to the draft card
    # whenever a draft exists, PersistDraftService writes `resource_terms = true`
    # on the record, and the models validate that on create only — so a draft in
    # flight at deploy would publish carrying an acceptance nobody was shown.
    # Asked here rather than backfilled, for the reason Account#terms_accepted?
    # gives.
    return Whatsapp::Flows::TermsConsentService.before_publish(conversation: @conversation) if
      !account.terms_accepted?

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
      return send_pending if resource.is_a?(Proposal) && !resource.admin_accepted?

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase(
          "whatsapp.bot.proposal.published", url: Whatsapp::PublishedResourceUrl.call(resource)
        )
      )
    end

    # Named without a link: until moderation accepts it the proposal has no
    # public page, and a link that answers with an error or a login wall reads
    # as a submission that went wrong. The copy says when it becomes openable
    # instead, and the moderation-decision push carries the link once it is.
    def send_pending
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.proposal.published_pending_moderation")
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
    # No consent exemption here, unlike CompleteDraftService: every model
    # validates `resource_terms` on create, this save is an update on a
    # persisted draft, so the error cannot reach this branch. Routing it to the
    # question anyway was worse than dead — accepting resumes the publish, which
    # would fail on the same unreachable error and ask again. The consent the
    # citizen owes is collected in #call, before anything is saved.
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
