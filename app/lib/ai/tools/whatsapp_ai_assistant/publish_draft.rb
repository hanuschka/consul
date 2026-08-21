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
              "phase's criteria reject the text; each refusal says what would resolve it. It also " \
              "refuses when the citizen has not been shown the contribution as it now stands: " \
              "call show_draft_for_confirmation, and call it again after any change to the draft. " \
              "On success the contribution is repeated to them for you, with its address or with " \
              "the sentence that it is waiting to be reviewed — so do not write it out again and " \
              "never offer a link of your own."

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
      refuse_if_not_permitted || refuse_without_consent || refuse_without_confirmation ||
        refuse_on_stale_preview
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
        hint: "Show them the contribution with show_draft_for_confirmation, offering a button " \
              "whose label says it submits. Call this again once they have answered that " \
              "question."
      }
    end

    PUBLISH_ACTIONS = %i[draft_publish submit_final].freeze

    # The second half of the same guarantee, and the half an offered button cannot
    # make. A button is offered against a message; the draft can be revised after
    # that message without the offer going anywhere, so the pill alone would let a
    # corrected contribution be published on a yes given to the version before the
    # correction — the citizen's own correction, published unread.
    #
    # So consent is held against the text rather than against the message: what was
    # rendered is digested when it is sent, and anything that changes what the block
    # shows revokes it.
    def refuse_on_stale_preview
      shown = conversation.draft_preview_digest

      return if shown.present? && shown == ::Whatsapp::DraftPreview.digest(conversation: conversation)

      {
        error: "The draft has changed since the citizen was last shown it, so their yes was " \
               "given to a different version and it was not published.",
        hint: "Call show_draft_for_confirmation so they see it as it now stands, and call this " \
              "again once they have answered."
      }
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
    # The phase id is reported because the reply is asked to offer taking part in the
    # same phase again, and that pill is parameterised: without the id here the model
    # has nothing to build it from and the offer is dropped as a record that does not
    # exist. Read before complete_draft! for the same reason the comment below gives —
    # the phase survives, but nothing else about the draft does.
    def published_answer(resource)
      url = ::Whatsapp::PublishedResourceUrl.call(resource)
      awaiting_review = resource.is_a?(::Proposal) && !resource.admin_accepted?
      projekt_phase_id = conversation.projekt_phase_id

      send_recap(url: awaiting_review ? nil : url)

      conversation.complete_draft!

      {
        published: true,
        awaiting_review: awaiting_review,
        url: awaiting_review ? nil : url,
        projekt_phase_id: projekt_phase_id,
        hint: awaiting_review ? AWAITING_REVIEW_HINT : PUBLISHED_HINT
      }.compact
    end

    # The contribution shown once more, composed from the record by the same renderer
    # that showed it before it went in — which is the point: a recap the model writes
    # is a recap that can differ from the preview it is meant to repeat, and the
    # citizen would have no way to tell which of the two the platform holds.
    #
    # Sent before complete_draft!, which drops the draft the renderer reads.
    def send_recap(url:)
      block =
        if url.present?
          ::Whatsapp::DraftPreview.published_block(conversation: conversation, url: url)
        else
          ::Whatsapp::DraftPreview.awaiting_review_block(conversation: conversation)
        end

      return if block.blank?

      ::Whatsapp::MessageBlock.chunks(block).each do |part|
        ::Whatsapp::Send.text(account: account, body: part)
      end
    end

    AWAITING_REVIEW_HINT = "It is in, but held for review. The contribution and the sentence " \
                           "saying it is waiting have already been sent to them, so do not " \
                           "repeat either and do not offer a link. Offer what follows: taking " \
                           "part in this same phase again, and their own contributions.".freeze

    # What plausibly follows a submission, which is not the same as an invitation to
    # submit again: the contribution they just made, the phase they made it in, and
    # the list of their own. Offering those is not pushiness — they have just acted,
    # and the alternative is a citizen reading "it is online" with nothing to do but
    # type. What stays out is anything unrelated to the thing they just did.
    #
    # The address has already gone out written into the recap rather than on a button
    # of its own, because a URL button is the only thing on the message it sits on:
    # taking it would cost the other two offers. WhatsApp makes a written-out address
    # tappable anyway.
    PUBLISHED_HINT = "The contribution and its address have already been sent to them, so do not " \
                     "repeat either and do not write a link. Say briefly that it is online and " \
                     "offer what follows from what they just did — taking part in this same " \
                     "phase again, and their own contributions — as buttons. Do not invite them " \
                     "to anything unrelated to the contribution they just submitted.".freeze

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
