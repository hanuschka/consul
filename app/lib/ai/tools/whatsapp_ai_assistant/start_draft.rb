class Ai::Tools::WhatsappAiAssistant::StartDraft < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Opens a submission against one participation phase, so everything drafted after " \
              "it belongs to that phase. Call it once the citizen has said they want to " \
              "contribute and which projekt or phase it is for. A place name on its own, a " \
              "reaction to something you showed them or a reply to a ballot question in front " \
              "of them is not that — at most a reason to ask whether they want to contribute. " \
              "It writes nothing the citizen can see and sends nothing — ask them for their " \
              "idea in your own words afterwards, or call draft_proposal straight away when " \
              "they have already told you it. It refuses while they are part-way through a " \
              "contribution or a comment: going back to the beginning is start_over, and " \
              "leaving that one for this is abort_submission first, once they have agreed to " \
              "lose it. What they asked for here is kept when it refuses."

  parameters do
    integer :projekt_phase_id,
      description: "Id of the open participation phase, from list_open_phases or describe_projekt"
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_IDEA
  end

  def execute(projekt_phase_id:)
    candidate = eligible_phase(projekt_phase_id)

    return unknown_phase_error if candidate.blank?

    # Starting a submission replaces the one in progress, and this used to do it
    # without a word: a typed "von vorne" restarted the same contribution in the
    # same projekt, where the citizen had asked to leave it. Losing what they wrote
    # now takes their yes, through AbortSubmission, which is the one discard. A
    # comment written and not yet posted is lost the same way, so it is asked
    # about the same way.
    #
    # What they asked for is held over the question rather than refused outright:
    # the idea came with the request, and after the yes it was gone with the draft.
    if conversation.unsaved_work?
      conversation.park_submission!(projekt_phase: candidate, text: citizen_words)

      return work_in_progress_error
    end

    conversation.start_draft!(candidate)

    # Asked after the phase is set rather than before, so the refusal is the one
    # this phase gives rather than the previous phase's — and the same check runs
    # again on every write that follows, because a phase can close between two
    # messages days apart.
    refusal = refuse_if_not_permitted

    return refusal if refusal.present?

    # Recorded before the consent question, which is already part of contributing.
    conversation.open_step!("contribution")

    consent = refuse_without_consent

    return consent if consent.present?

    {
      started: true,
      projekt: projekt_title(candidate.projekt),
      phase: candidate.title,
      collects_picture: conversation.image_question_available?,
      collects_location: conversation.location_question_available?,
      next_step: "Ask the citizen what they want to contribute, then call draft_proposal with " \
                 "their own words."
    }
  end

  private

    def work_in_progress_error
      {
        error: "The citizen is part-way through #{unsaved_work_name}, so nothing was started: a " \
               "new contribution would throw away what they have written. What they asked for " \
               "here is kept.",
        hint: "If they asked to go back to the beginning, call start_over. Otherwise say in one " \
              "line what is unsaved and ask whether to discard it or keep it. On discard call " \
              "abort_submission, whose answer carries on with what they asked for here. On keep " \
              "say that this new one is kept too and that you will come back to it once the " \
              "other is published or discarded, then go on with the other."
      }
    end

    def unsaved_work_name
      conversation.unsaved_submission? ? "a contribution" : "a comment"
    end
end
