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
              "the citizen to contribute, when a category or sentiment is missing, when the phase " \
              "takes a picture and the citizen has not been asked for one with request_photo, " \
              "when the phase takes a place and it has not been asked about yet, or " \
              "when the phase's criteria reject the text; each refusal says what would resolve " \
              "it. It also " \
              "refuses when the citizen has not been shown the contribution as it now stands: " \
              "call show_draft_for_confirmation, and call it again after any change to the draft. " \
              "On success the citizen is told for you that it went in, with its address or with " \
              "the sentence that it is waiting to be reviewed — so do not say either yourself and " \
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
    # The picture and place questions sit before it, because answering either
    # changes the draft the confirmation would be given to.
    def precondition_refusal
      refuse_if_not_permitted || refuse_without_consent || refuse_without_image_question ||
        refuse_without_location_question || refuse_without_confirmation ||
        refuse_on_stale_preview
    end

    # A phase that takes pictures asks for one before anything goes in, because
    # nothing can be added to a published contribution from the chat.
    def refuse_without_image_question
      return if conversation.image_question_settled?

      {
        error: "This phase takes a picture and the citizen has not been asked for one, so it " \
               "was not published. Nothing can be added to it once it is in.",
        hint: "Ask for the picture with request_photo, which carries the notices that have to " \
              "come with it. Once they have answered, show them the contribution again with " \
              "show_draft_for_confirmation."
      }
    end

    # The place, for the same reason and after the picture, in the order the
    # preview names them. The bot tells the citizen it will ask for both, so a
    # contribution that goes in without the second question is one that broke
    # that promise — on a map nothing can be pinned from the chat afterwards.
    # Asked, not answered: opening the picker once or a "no" settles it.
    def refuse_without_location_question
      return if conversation.location_question_settled?

      {
        error: "This phase takes a place and the citizen has not been asked about it, so it " \
               "was not published. Nothing can be added to it once it is in.",
        hint: "Call draft_status for the place: attach one that is waiting with " \
              "set_draft_location once they agree to it, or offer the pin with " \
              "request_location. Once they have answered, show them the contribution again " \
              "with show_draft_for_confirmation — with location_declined where they said " \
              "they would rather go without one."
      }
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
        hint: "Show them the contribution with show_draft_for_confirmation, which adds the " \
              "button that submits once nothing is left to ask. Call this again once they have " \
              "answered that question."
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
    # The phase id is reported so that another idea, once asked for, can be offered
    # in the same phase again. So it is read before complete_draft! drops it.
    def published_answer(resource)
      url = ::Whatsapp::PublishedResourceUrl.call(resource)
      awaiting_review = resource.is_a?(::Proposal) && !resource.admin_accepted?
      projekt_phase_id = conversation.projekt_phase_id

      send_confirmation(url: awaiting_review ? nil : url)

      conversation.complete_draft!
      conversation.note_submission_completed!

      ::Whatsapp::StatePills.focus_submission_completed

      {
        completed: true,
        published: true,
        awaiting_review: awaiting_review,
        url: awaiting_review ? nil : url,
        projekt_phase_id: projekt_phase_id,
        hint: awaiting_review ? AWAITING_REVIEW_HINT : PUBLISHED_HINT
      }.compact
    end

    # The outcome and nothing else. The citizen has just read the contribution and
    # answered the question under it, so the only thing this message can add is where
    # it went — and sending it from here rather than leaving it to the model is what
    # keeps the address the platform's own rather than one the model recalled.
    def send_confirmation(url:)
      block =
        if url.present?
          ::Whatsapp::DraftPreview.published_confirmation(conversation: conversation, url: url)
        else
          ::Whatsapp::DraftPreview.awaiting_review_confirmation(conversation: conversation)
        end

      ::Whatsapp::Send.message_block(account: account, block: block)
    end

    # What plausibly follows a submission: another idea, the list of their own and the
    # projekts. Offering those is not pushiness — they have just acted, and the
    # alternative is a citizen reading "it is online" with nothing to do but type.
    # What stays out is anything unrelated to the thing they just did, and a support
    # for it, which its author cannot give.
    #
    # The buttons are Whatsapp::StatePills' rather than the model's, so the sentence
    # is told which three they are: it offered another idea in words while the slots
    # under it carried something else.
    NEXT_STEPS = "Three buttons are put under your reply for you: submitting another idea, their " \
                 "own contributions, and the projekts. Offer exactly those in a short line, add " \
                 "no buttons of your own, and do not invite them to support or comment on the " \
                 "contribution they just submitted.".freeze

    AWAITING_REVIEW_HINT = "It is in, but held for review. They have already been told that it " \
                           "arrived and is with the administration, so do not say it again, do " \
                           "not repeat the contribution and do not offer a link. " \
                           "#{NEXT_STEPS}".freeze

    # That it is online is said once, in the message this tool has already sent, and
    # a model that says it again turns one fact into two messages carrying it. So the
    # buttons arrive under the offers alone.
    #
    # The address went out written into that message rather than on a button of its
    # own, because a URL button is the only thing on the message it sits on: taking it
    # would cost the three offers. WhatsApp makes a written-out address tappable
    # anyway.
    PUBLISHED_HINT = "They have already been told that it is online, and its address has already " \
                     "been sent to them, so do not say either again and do not repeat the " \
                     "contribution. #{NEXT_STEPS}".freeze

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
