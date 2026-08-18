class Whatsapp::Flows::ContinueOrRestartService < Whatsapp::Flows::BaseService
  # The question asked when a message carries no substance of its own and the
  # bot was waiting on free text: "hallo" at the idea step used to become the
  # text of a contribution, draft generation and all (CON-2968). Reached from
  # the classifier gate (Inbound::ProcessMessageService#handle_fresh_start) and
  # from the router's AskContinueOrRestart tool, which are the same reading
  # arriving by the two paths a message can take.
  #
  # The sibling of ResumeOrRestartService, and deliberately not it: that one
  # asks about a flow abandoned hours ago and has to quote the projekt and the
  # draft back before the citizen can choose. This one interrupts someone who
  # is still in the conversation, so the question stands on its own.
  def self.ask(conversation:)
    new(conversation: conversation).ask
  end

  def self.continue(conversation:)
    new(conversation: conversation).continue
  end

  def self.restart(conversation:)
    new(conversation: conversation).restart
  end

  # Shared with the taxonomy questions rather than counted separately: a
  # citizen who keeps greeting is answering neither, and the budget belongs to
  # the unanswered question, not to which question it was.
  MAX_REASKS = Whatsapp::Flows::AskDraftChoiceService::MAX_REASKS

  # Asked at most MAX_REASKS times. Without the bound, a greeting answered by
  # this question and answered again with a greeting is a loop the citizen
  # cannot leave by writing — AWAITING_CONTINUE_DECISION is itself a
  # fresh-start step, so the same reading is available on the question.
  # Giving up cancels: the submission is what the greetings are not carrying
  # on with, and CancelService leaves one button back to the menu.
  def ask
    return abandon if @conversation.choice_reasks >= MAX_REASKS

    @conversation.ask_continue_decision!(interrupted_step)

    Whatsapp::Send.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.continue_or_restart"),
      buttons: buttons
    )
  end

  # Back to where they were, with everything already collected untouched:
  # resume_interrupted_step! restores the step and drops only the two keys the
  # question itself owns, and the prompt is then re-sent by the step's own
  # service so the citizen reads the question they were answering rather than
  # having to scroll for it.
  #
  # The step is restored before the prompt is sent, not after: every service
  # below writes its own step, and one that also reads the conversation's
  # state must see the restored one.
  def continue
    interrupted = @conversation.interrupted_step

    return Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation) if
      interrupted.blank?

    @conversation.resume_interrupted_step!

    re_send_prompt(interrupted)
  end

  # Exactly what the citizen asked for: reset_flow! drops the pending draft and
  # CancelService's one button is the way to the menu. The main menu is not
  # sent unasked on top of it — a message and a tap is what starting over is
  # worth, and the same service answers the typed "abbrechen".
  def restart
    abandon
  end

  private

    # On a re-ask, the step the *first* asking recorded. A second greeting
    # arrives with the conversation already on the question —
    # AWAITING_CONTINUE_DECISION is itself a fresh-start step — and recording
    # that as the interrupted step made "Weitermachen" resume the question
    # instead of the submission: re_send_prompt has no case for it, so the tap
    # fell through to the menu, whose reset_flow! threw the half-written
    # submission away. It is also what keeps the two comments below true.
    def interrupted_step
      return @conversation.interrupted_step if
        @conversation.step == Whatsapp::Conversation::Step::AWAITING_CONTINUE_DECISION

      @conversation.step
    end

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :continue_flow, label_key: "whatsapp.bot.buttons.continue_flow"
        ),
        Whatsapp::FlowActions.button(
          action: :start_over, label_key: "whatsapp.bot.buttons.start_over"
        )
      ]
    end

    def abandon
      Whatsapp::Flows::CancelService.call(conversation: @conversation)
    end

    # Each step's own prompt, by the entry point that re-asks rather than the
    # one that first arrives at the step: AskRevisionService.re_ask leaves the
    # origin the draft card recorded alone, ProposalImageService.ask_upload
    # asks for the photo instead of re-offering the choice the citizen already
    # made, and AskLocationService.re_ask puts the pin question without
    # spending the one miss #remind would.
    #
    # AWAITING_PHASE_CHOICE is absent because nothing assigns that step, and
    # AWAITING_CONTINUE_DECISION cannot appear — the question records the step
    # it interrupted, never its own. Anything unmapped is the menu, which is
    # also where a comment whose proposal has since gone lands.
    def re_send_prompt(interrupted)
      steps = Whatsapp::Conversation::Step

      case interrupted
      when steps::AWAITING_IDEA
        Whatsapp::Flows::AskIdeaService.call(conversation: @conversation)
      when steps::AWAITING_COMMENT
        re_send_comment_prompt
      when steps::AWAITING_IMAGE_UPLOAD
        Whatsapp::Flows::ProposalImageService.ask_upload(conversation: @conversation)
      when steps::AWAITING_REVISION
        Whatsapp::Flows::AskRevisionService.re_ask(conversation: @conversation)
      when steps::AWAITING_LOCATION
        Whatsapp::Flows::AskLocationService.re_ask(conversation: @conversation)
      when steps::AWAITING_PARTICIPATION_PROJEKT
        Whatsapp::Flows::ProjektParticipationService.ask_projekt(conversation: @conversation)
      else
        Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation)
      end
    end

    # The comment question needs the record it is about, and it can be gone by
    # now — deleted, or its projekt closed. The menu is the honest answer then:
    # asking for a comment again would invite one that nothing would accept.
    def re_send_comment_prompt
      proposal = Proposal.find_by(id: @conversation.comment_proposal_id)

      return Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation) if
        proposal.blank?

      Whatsapp::Flows::CommentService.prompt(conversation: @conversation, proposal: proposal)
    end
end
