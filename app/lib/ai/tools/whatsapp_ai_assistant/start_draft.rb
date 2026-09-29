class Ai::Tools::WhatsappAiAssistant::StartDraft < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Opens a submission against one participation phase, so everything drafted after " \
              "it belongs to that phase. Call it once the citizen has said they want to " \
              "contribute and which projekt or phase it is for. A place name on its own, a " \
              "reaction to something you showed them or a reply to a ballot question in front " \
              "of them is not that — at most a reason to ask whether they want to contribute. " \
              "It writes nothing the citizen can see and sends nothing — ask them for their " \
              "idea in your own words afterwards, or call draft_proposal straight away when " \
              "they have already told you it. It refuses while they are part-way through a " \
              "contribution: going back to the beginning is start_over, and leaving this one " \
              "for another is abort_submission first, once they have agreed to lose it."

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
    # now takes their yes, through AbortSubmission, which is the one discard.
    return submission_in_progress_error if conversation.unsaved_submission?

    conversation.start_draft!(candidate)

    # Asked after the phase is set rather than before, so the refusal is the one
    # this phase gives rather than the previous phase's — and the same check runs
    # again on every write that follows, because a phase can close between two
    # messages days apart.
    refusal = refuse_if_not_permitted

    return refusal if refusal.present?

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

    def submission_in_progress_error
      {
        error: "The citizen is part-way through a contribution, so nothing was started: a new " \
               "one would throw away what they have written.",
        hint: "If they asked to go back to the beginning, call start_over. If they want to " \
              "leave this contribution for another, say in one line what is unsaved and ask " \
              "whether to discard it; call abort_submission only on their yes, then this."
      }
    end
end
