class Whatsapp::Flows::ResumeOrRestartService < Whatsapp::Flows::BaseService
  # Catalog C23. Sent as a reply the next time the citizen writes in, never
  # pushed: WhatsApp only carries a freeform message within 24 hours of their
  # last one, and the staleness threshold is 3600 minutes — so by the time a
  # draft is stale the bot could not reach out even if it wanted to.
  def self.resume(conversation:)
    new(conversation: conversation).resume
  end

  def self.restart(conversation:)
    new(conversation: conversation).restart
  end

  # The recap goes first either way: hours or days passed since the draft was
  # started, and the step being resumed says nothing about which projekt it
  # belongs to. The draft can also be gone by then — retention purges, an
  # admin deleting the phase — in which case the idea is asked for again
  # inside the same phase rather than sending the citizen back to the entry
  # question.
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
    @conversation.merge_context!(flow_started_at: Time.current.iso8601)

    send_recap

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
      body: Whatsapp.phrase("whatsapp.bot.proposal.resume"),
      buttons: buttons
    )
  end

  # How much of the citizen's idea the recap quotes back.
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

    # Sent before the step being resumed, never instead of it. The resume
    # question is answered hours or days after the citizen left, so what they
    # land back on has to say what it is about first.
    #
    # The draft is deliberately not repeated here: when one exists the resumed
    # step is the draft card itself, which carries the title and description
    # one message later, and only the projekt is missing from it. Without a
    # draft nothing else would say what the citizen had already typed, so the
    # idea comes back with the recap.
    def send_recap
      return if projekt.blank?

      Whatsapp::Send.text(account: account, body: recap_body)
    end

    def projekt
      @conversation.projekt_phase&.projekt
    end

    def recap_body
      recap = Whatsapp.phrase(
        "whatsapp.bot.proposal.resume_recap", projekt: Whatsapp::ProjektLink.title(projekt)
      )

      [recap, idea_recap].compact_blank.join("\n\n")
    end

    # The text the citizen sent before the generation call, kept by
    # BuildDraftService for its own retry path. Read rather than stored a second
    # time: a draft that failed to generate leaves exactly this behind, which is
    # the case the citizen most needs quoted back.
    def idea_recap
      return if @conversation.draft_resource.present?

      idea_text = @conversation.context["last_idea_text"].to_s.squish

      return if idea_text.blank?

      Whatsapp.phrase(
        "whatsapp.bot.proposal.resume_recap_idea", idea: idea_text.truncate(IDEA_PREVIEW_LENGTH)
      )
    end
end
