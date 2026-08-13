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

    Whatsapp::Flows::ResumeRecapService.call(conversation: @conversation)

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

    Whatsapp::Outbound.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.resume"),
      buttons: buttons
    )
  end

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
end
