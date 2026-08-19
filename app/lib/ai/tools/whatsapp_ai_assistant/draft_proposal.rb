class Ai::Tools::WhatsappAiAssistant::DraftProposal < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The citizen's idea turned into a draft contribution, on the same generation the
  # web submission form uses. It returns the draft as data rather than sending
  # anything: what the citizen reads about their own draft is a sentence, and the
  # draft under it is their words, so the presenting belongs to the model.
  #
  # Revisions are unlimited by design, so the abuse guard is a rate limit per
  # conversation rather than a cap on rounds.
  DRAFT_INTERVAL = 15.seconds

  # The screening call is throttled separately and far more loosely. It has to be
  # throttled at all — a refused text is invited to be rewritten, so without a floor
  # the refusal loop is an unbounded completion-per-message hole that never reaches
  # a draft. But it cannot share the drafting floor: fifteen seconds would answer
  # the rewrite its own refusal just asked for with "you are too fast".
  SCREENING_INTERVAL = 3.seconds

  DESCRIPTION_LENGTH = 700

  description "Writes the citizen's idea up as a draft contribution to the phase this submission " \
              "belongs to, and returns it for you to show them. Pass their own words, complete and " \
              "unchanged — never your summary of them: this is their contribution and the " \
              "generation reads what they actually wrote. Call start_draft first if no phase has " \
              "been chosen. It also returns anything already submitted that looks like the same " \
              "idea, and the phase's own assessment of the draft where the phase sets criteria. " \
              "Nothing is published by this. Show them the draft in your own words, raise any " \
              "near-duplicate as a genuine question — supporting one that exists is often worth " \
              "more than a second copy of it — and offer to revise or to publish."

  params do
    string :text,
      description: "What the citizen wrote, word for word, including everything they said about " \
                   "the place and any photo. Never a paraphrase."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_DRAFT_DECISION
  end

  def execute(text:)
    idea_text = text.to_s.strip

    return blank_idea_error if idea_text.blank?

    refusal = precondition_refusal

    return refusal if refusal.present?
    return too_fast_error if throttled?

    # Stored before the screening gate because a later retry reads it back, and
    # after a refused check it is the only copy of what the citizen wrote.
    conversation.store_idea_text!(idea_text)

    build(idea_text)
  rescue StandardError => e
    report(e)

    generation_failed_error
  end

  private

    def precondition_refusal
      refuse_without_consent || refuse_if_not_permitted
    end

    def build(idea_text)
      # Armed inside the gate it guards rather than above it, so a text that never
      # reaches the screening does not re-arm the floor against the next real idea.
      conversation.stamp_screened!

      # Screened before anything is generated: a text that is about to be refused
      # should not first cost a generation.
      safety = ::ProposalAiDraft::EvaluateContentSafetyService.with_search_terms(
        idea_text: idea_text
      )

      return safety_unavailable_error if !safety.success?
      return refused_content_error(safety.reason) if safety.reason.present?

      generated = ::ProposalAiDraft::GenerateDraftService.with_required_taxonomy(
        idea_text: idea_text, projekt_phase: projekt_phase
      ).to_h

      # One write under the advisory lock: the draft, its card summary, the
      # questions the citizen already answered unasked, and the drafting clock.
      conversation.store_generated_draft!(generated)

      answer(::Whatsapp::Drafting::CompleteDraftService.call(conversation: conversation), safety)
    end

    # The three things the model needs and cannot see: the draft as it stands, what
    # the portal already holds that resembles it, and how the phase's own criteria
    # judged it.
    def answer(stored, safety)
      return invalid_draft_error(stored.errors) if stored.invalid?
      return missing_choice_answer(stored.missing) if stored.missing?

      {
        draft: draft_payload(stored.resource),
        similar_contributions: similar_contributions(safety.search_terms),
        assessment: assessment_for(stored.resource),
        collects_picture: conversation.image_question_available?,
        collects_location: conversation.location_question_available?
      }.compact
    end

    def draft_payload(resource)
      {
        title: resource.title,
        text: ::Whatsapp.plain_text(resource.description, length: DESCRIPTION_LENGTH),
        category: ::Whatsapp::DraftTaxonomy.category(projekt_phase).display_name(resource),
        sentiment: ::Whatsapp::DraftTaxonomy.sentiment(projekt_phase).display_name(resource)
      }.compact
    end

    # The choice the generation left open, with the options the phase really offers.
    # Rare by construction — the drafting schema forces a valid pick wherever the
    # provider enforces schemas — so this covers a non-strict provider's stray
    # answer or an option removed between the two calls.
    def missing_choice_answer(kind)
      requirement = ::Whatsapp::DraftTaxonomy.requirements(projekt_phase)
        .find { |candidate| candidate.kind == kind }

      {
        error: "The draft is written but cannot be saved until the citizen chooses a #{kind}. " \
               "Ask them, offering these options, and call set_draft_#{kind} with their answer.",
        options: requirement.options.map do |option|
          { label: option.name, option_id: option.id, action_id: "#{kind}-#{option.id}" }
        end
      }
    end

    # The search runs on the citizen's words and on the words a duplicate might have
    # been written with instead: matching tokens alone, "Zebrastreifen" and
    # "Fußgängerüberweg" are two unrelated proposals. Judging which of them is
    # actually the same idea used to be a second model call of its own; it is a
    # judgement, so it belongs to the model that is already reading the draft.
    def similar_contributions(search_terms)
      candidates = ::Whatsapp::SimilarProposalsQuery.call(
        projekt_phase: projekt_phase,
        text: conversation.last_idea_text,
        extra_terms: search_terms
      )

      return if candidates.blank?

      candidates.map do |proposal|
        {
          contribution_id: proposal.id,
          title: proposal.title,
          supports: proposal.cached_votes_up,
          url: ::Whatsapp::PublishedResourceUrl.call(proposal),
          action_id: "support-#{proposal.id}"
        }.compact
      end
    end

    # Only where the phase sets criteria of its own. A hard failure is not a refusal
    # here — the citizen may still revise — but it is the reason publish_draft will
    # refuse, so the model is told now rather than after they have confirmed.
    def assessment_for(resource)
      return if !projekt_phase.user_resource_criteria.exists?

      evaluation = stored_evaluation(resource) ||
                   ::ProposalAiDraft::EvaluateTwoTierService.call(resource: resource).to_h

      return if evaluation.blank?

      {
        stage: evaluation["stage"],
        score: evaluation["total_score"],
        feedback: evaluation["overall_feedback"].to_s.squish.presence,
        failed_criterion: failed_criterion(evaluation)
      }.compact
    end

    # The draft card already evaluated this exact text: PersistDraftService clears
    # the stored result whenever the draft is rewritten, so a verdict that is present
    # is about what is on the table now. An error is not a verdict, so it is not
    # reused.
    def stored_evaluation(resource)
      evaluation = resource.ai_evaluation_result.to_h

      return if evaluation["stage"].blank?
      return if evaluation["stage"] == ::ProposalAiDraft::EvaluateTwoTierService::STAGE_ERROR

      evaluation
    end

    def failed_criterion(evaluation)
      criterion = evaluation["failed_criterion"].to_h

      return if criterion.blank?

      {
        name: criterion["name"],
        feedback: criterion["citizen_feedback"].presence || criterion["feedback"]
      }.compact
    end

    # Two clocks, because the two calls this tool makes cost differently and are
    # reached differently: a draft is the expensive one and is followed by something
    # to read, a screening is the cheap one and may be followed straight away by the
    # rewrite its refusal asked for.
    def throttled?
      within?(conversation.last_draft_at, DRAFT_INTERVAL) ||
        within?(conversation.last_screened_at, SCREENING_INTERVAL)
    end

    def within?(stamped_at, interval)
      return false if stamped_at.blank?

      Time.zone.parse(stamped_at) > interval.ago
    end

    def blank_idea_error
      { error: "There is nothing to draft from. Ask the citizen what they want to contribute." }
    end

    def too_fast_error
      { error: "A draft for this conversation was written moments ago. Tell the citizen it is " \
               "still being worked on and ask them to wait a few seconds." }
    end

    def refused_content_error(reason)
      {
        error: "This text cannot be submitted.",
        reason: reason.to_s,
        hint: "Tell the citizen plainly why, without repeating what they wrote, and invite them " \
              "to put it differently. Nothing has been saved."
      }
    end

    # Fail closed. The alternative is publishing whatever the check could not read,
    # and a submission postponed by an outage is recoverable in a way a published
    # slur is not.
    def safety_unavailable_error
      { error: "The content check could not be reached, so nothing was drafted. Tell the citizen " \
               "it did not work this time and offer to try again in a moment." }
    end

    def generation_failed_error
      { error: "Writing the draft failed. Tell the citizen it did not work and offer to try " \
               "again — their own words have been kept." }
    end

    def report(exception)
      Rails.logger.error(
        "[Whatsapp] draft generation failed: #{exception.class} - #{exception.message}"
      )

      Sentry.capture_exception(exception, extra: { whatsapp_conversation_id: conversation.id })
    end
end
