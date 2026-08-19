class Ai::Tools::WhatsappAiAssistant::PublishDraft < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The one irreversible tool in the submission, and therefore the one that carries
  # the preconditions the retired step machine used to guarantee by sequence.
  # Nothing between a citizen and an unconsented, out-of-phase or half-finished
  # submission now stands anywhere else: consent, permission, completeness and the
  # phase's own criteria are all checked here, and each refuses rather than warns.
  #
  # Published cannot be undone from a chat, so every one of these refusals is a
  # refusal the model cannot talk its way past — it gets data back saying no, not a
  # rule it is asked to respect.
  description "Publishes the draft, which cannot be undone from this chat. Call it only once the " \
              "citizen has clearly said the draft should go in as it stands — never on a message " \
              "that merely agrees with something else, and never to move things along. Call " \
              "draft_status first if you are not certain nothing is outstanding. It refuses on " \
              "its own when the terms have not been accepted, when the phase no longer allows " \
              "the citizen to contribute, when a category or sentiment is missing, or when the " \
              "phase's criteria reject the text; each refusal says what would resolve it. On " \
              "success tell them where the contribution is, or that it is waiting to be " \
              "reviewed — a contribution waiting for review has no public page yet, so do not " \
              "offer a link to one."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::IDLE
  end

  def execute
    return no_draft_error if !conversation.unsaved_submission?

    refusal = precondition_refusal

    return refusal if refusal.present?

    stored = ::Whatsapp::Drafting::CompleteDraftService.call(conversation: conversation)

    return invalid_draft_error(stored.errors) if stored.invalid?
    return incomplete_error(stored.missing) if stored.missing?
    return no_draft_error if stored.resource.blank?

    publish
  end

  private

    # Consent before permission, because the two refusals ask for different things
    # and the citizen should not be sent to accept terms for a phase that has closed.
    def precondition_refusal
      refuse_if_not_permitted || refuse_without_consent
    end

    def publish
      result = ::Whatsapp::Drafting::PublishDraftService.call(conversation: conversation)

      return criteria_failed_error if result == :criteria_failed
      return incomplete_error(:category) if result == :category_missing
      return incomplete_error(:sentiment) if result == :sentiment_missing
      return invalid_draft_error(draft_errors) if result == :invalid
      return unavailable_error if result.blank?

      published_answer(result)
    end

    # The phase is kept so the citizen's next idea goes to the same one; everything
    # about the draft is dropped, because it is a published record now and nothing
    # about it is still a draft.
    def published_answer(resource)
      url = ::Whatsapp::PublishedResourceUrl.call(resource)
      awaiting_review = resource.is_a?(::Proposal) && !resource.admin_accepted?

      conversation.complete_draft!

      {
        published: true,
        awaiting_review: awaiting_review,
        url: awaiting_review ? nil : url,
        hint: awaiting_review ? AWAITING_REVIEW_HINT : PUBLISHED_HINT
      }.compact
    end

    AWAITING_REVIEW_HINT = "It is in, but held for review, so it has no public page yet. Say " \
                           "that plainly, say they will hear when it is decided, and do not " \
                           "offer a link.".freeze

    PUBLISHED_HINT = "Tell them it is online and give them the link with send_link. Do not " \
                     "invite them to submit something else unless they ask.".freeze

    def draft_errors
      conversation.draft_resource&.errors&.full_messages
    end

    def incomplete_error(missing)
      {
        error: "The draft is missing the #{missing} this phase requires, so it cannot go in yet.",
        hint: "Ask the citizen for it, offering the options draft_status returns, and record it " \
              "with set_draft_#{missing}."
      }
    end

    # The phase's own hard criteria rejected the text. The citizen is the only one who
    # can change it, and a retry of the same words fails identically, so what the
    # model owes them is the criterion and an offer to revise.
    def criteria_failed_error
      criterion = conversation.draft_resource.ai_evaluation_result.to_h["failed_criterion"].to_h

      {
        error: "This phase's criteria reject the draft as it stands, so it was not published.",
        criterion: criterion["name"],
        feedback: criterion["citizen_feedback"].presence || criterion["feedback"],
        hint: "Say what the criterion asks for, in your own words and without blaming them, and " \
              "offer to revise the draft with revise_draft. Nothing has been published."
      }.compact
    end

    # The evaluator swallows its own exceptions and answers with an error stage, so an
    # unreachable evaluation used to read as a pass and publish drafts the phase's
    # criteria had never approved. It is a reason not to publish yet.
    def unavailable_error
      { error: "Publishing could not be completed — the checks the phase requires could not be " \
               "reached. Tell the citizen it did not work this time, that nothing has been lost, " \
               "and offer to try again in a moment." }
    end
end
