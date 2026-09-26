class Ai::Tools::WhatsappAiAssistant::StartDraft < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Opens a submission against one participation phase, so everything drafted after " \
              "it belongs to that phase. Call it once the citizen has said which projekt or phase " \
              "they want to contribute to. It writes nothing the citizen can see and sends " \
              "nothing — ask them for their idea in your own words afterwards, or call " \
              "draft_proposal straight away when they have already told you it. Whatever draft " \
              "was open is discarded, so do not call it while they are part-way through one " \
              "unless they have said they want to start again."

  params do
    integer :projekt_phase_id,
      description: "Id of the open participation phase, from list_open_phases or describe_projekt"
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_IDEA
  end

  def execute(projekt_phase_id:)
    candidate = eligible_phase(projekt_phase_id)

    return unknown_phase_error if candidate.blank?

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
end
