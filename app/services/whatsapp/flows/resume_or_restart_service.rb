class Whatsapp::Flows::ResumeOrRestartService < Whatsapp::Flows::BaseService
  # Catalog C23. Sent as a reply the next time the citizen writes in, never
  # pushed: the staleness check sits in the inbound gate chain
  # (Inbound::ProcessMessageService#handle_stale_flow), so nothing consults it
  # until they write. That is what keeps the question inside WhatsApp's
  # 24-hour service window whatever Conversation::STALE_FLOW_AFTER is set to.
  def self.resume(conversation:)
    new(conversation: conversation).resume
  end

  def self.restart(conversation:)
    new(conversation: conversation).restart
  end

  # Straight into the step being resumed: the question that got here already
  # named the projekt and quoted what was on the table, so there is nothing
  # left to recap. The draft can be gone by now — retention purges, an admin
  # deleting the phase — in which case the idea is asked for again inside the
  # same phase rather than sending the citizen back to the entry question.
  #
  # A phase deleted outright leaves nothing to resume into and nothing for
  # AskIdeaService to move the step with, so it restarts instead — otherwise
  # every later message would re-ask the resume question it cannot answer.
  def resume
    return restart if @conversation.projekt_phase.blank?

    # The clock the staleness question is asked off is only stamped by
    # start_flow!, and resuming moves the step without going through it. Left
    # alone, the resumed step would be found stale again by the citizen's very
    # next message and the same question asked forever.
    @conversation.stamp_flow_started!

    if @conversation.draft_resource.present?
      return Whatsapp::Flows::PresentDraftService.first_draft(conversation: @conversation)
    end

    Whatsapp::Flows::AskIdeaService.call(conversation: @conversation)
  end

  # Starting over drops the draft and asks the entry question again rather
  # than the idea question: by the time the resume prompt is answered the
  # citizen may not remember which projekt the conversation was in, and "tell
  # me your idea" names none. SubmitProposalService re-derives what is open,
  # so a phase that closed in the meantime cannot be restarted into.
  def restart
    @conversation.reset_flow!

    Whatsapp::Flows::SubmitProposalService.call(conversation: @conversation)
  end

  def call
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_RESUME_DECISION)

    Whatsapp::Send.buttons(
      account: account,
      body: question_body,
      buttons: buttons
    )
  end

  # How much of the citizen's idea the resume question quotes back.
  IDEA_PREVIEW_LENGTH = 300

  private

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :resume, label_key: "whatsapp.bot.buttons.resume"
        ),
        Whatsapp::FlowActions.button(
          action: :restart, label_key: "whatsapp.bot.buttons.restart"
        )
      ]
    end

    # This is the one question in the flow a citizen cannot answer without
    # being told what it is about: hours or days have passed, and "your earlier
    # contribution" names neither the projekt nor what they wrote. Both facts
    # used to be sent — but in a recap after they had already chosen, which is
    # exactly one message too late to help them choose.
    def question_body
      [
        Whatsapp.phrase("whatsapp.bot.proposal.resume"),
        projekt_line,
        subject_line
      ].compact_blank.join("\n\n")
    end

    def projekt
      @conversation.projekt_phase&.projekt
    end

    def projekt_line
      return if projekt.blank?

      Whatsapp.phrase(
        "whatsapp.bot.proposal.resume_projekt", projekt: Whatsapp::ProjektLink.title(projekt)
      )
    end

    # What is on the table, quoted so the choice is about something. A draft
    # that exists is named by its title — continuing sends the card with the
    # whole thing one message later — and a submission that never reached one
    # falls back to the citizen's own words, which is also the case where
    # nothing else would ever show them again.
    def subject_line
      draft = @conversation.draft_resource

      return Whatsapp.phrase("whatsapp.bot.proposal.resume_draft", title: draft.title.to_s) if
        draft.present?

      idea_line
    end

    # The text the citizen sent before the generation call, kept by
    # BuildDraftService for its own retry path. Read rather than stored a second
    # time: a draft that failed to generate leaves exactly this behind, which is
    # the case the citizen most needs quoted back.
    def idea_line
      idea_text = @conversation.last_idea_text.to_s.squish

      return if idea_text.blank?

      Whatsapp.phrase(
        "whatsapp.bot.proposal.resume_recap_idea", idea: idea_text.truncate(IDEA_PREVIEW_LENGTH)
      )
    end
end
