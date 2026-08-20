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
    # The confirmation comes last: it is the only one of the three the citizen can
    # resolve in a single message, so it is worth asking for only once the rest holds.
    def precondition_refusal
      refuse_if_not_permitted || refuse_without_consent || refuse_without_confirmation
    end

    # The guarantee the retired step machine made structurally: it had two steps that
    # could only be answered once a card had been sent, so nothing could be published
    # that the citizen had not seen. Nothing about the tools reproduces that — a model
    # could go from an idea to a published contribution inside one turn — so it is a
    # precondition here, and checked against what the bot really put in front of them
    # rather than against the model's account of the conversation.
    def refuse_without_confirmation
      return if PUBLISH_ACTIONS.any? { |action| conversation.confirmation_offered?(action) }

      {
        error: "The citizen has not been shown this draft and asked whether it should go in, so " \
               "it was not published.",
        hint: "Show them the draft as it stands — send_draft_card when it has a picture, " \
              "reply_with_actions otherwise — with a button whose label says it submits. Call " \
              "this again once they have answered that question."
      }
    end

    PUBLISH_ACTIONS = %i[draft_publish submit_final].freeze

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
    # The phase id is reported because the reply is asked to offer taking part in the
    # same phase again, and that pill is parameterised: without the id here the model
    # has nothing to build it from and the offer is dropped as a record that does not
    # exist. Read before complete_draft! for the same reason the comment below gives —
    # the phase survives, but nothing else about the draft does.
    def published_answer(resource)
      url = ::Whatsapp::PublishedResourceUrl.call(resource)
      awaiting_review = resource.is_a?(::Proposal) && !resource.admin_accepted?
      projekt_phase_id = conversation.projekt_phase_id

      conversation.complete_draft!

      {
        published: true,
        awaiting_review: awaiting_review,
        url: awaiting_review ? nil : url,
        projekt_phase_id: projekt_phase_id,
        hint: awaiting_review ? AWAITING_REVIEW_HINT : PUBLISHED_HINT
      }.compact
    end

    AWAITING_REVIEW_HINT = "It is in, but held for review, so it has no public page yet. Say " \
                           "that plainly, say they will hear when it is decided, and do not " \
                           "offer a link.".freeze

    # What plausibly follows a submission, which is not the same as an invitation to
    # submit again: the contribution they just made, the phase they made it in, and
    # the list of their own. Offering those is not pushiness — they have just acted,
    # and the alternative is a citizen reading "it is online" with nothing to do but
    # type. What stays out is anything unrelated to the thing they just did.
    #
    # The link goes in the reply's text rather than on a button of its own, because a
    # URL button is the only thing on the message it sits on: taking it would cost the
    # other two offers. WhatsApp makes a written-out address tappable anyway, so all
    # three arrive tappable in one message.
    PUBLISHED_HINT = "Tell them it is online, with the address written out in the text so they " \
                     "can open it. Offer what follows from what they just did — taking part in " \
                     "this same phase again, and their own contributions — as buttons beside it. " \
                     "Do not invite them to anything unrelated to the contribution they just " \
                     "submitted.".freeze

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
