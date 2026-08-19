class Whatsapp::Flows::ContinueOrRestartService < Whatsapp::Flows::BaseService
  # The question asked when a message carries no substance of its own, the bot
  # was waiting on free text, and there is something half-written to carry on
  # with: "hallo" at the idea step used to become the text of a contribution,
  # draft generation and all (CON-2968). Reached from the classifier gate
  # (Inbound::ProcessMessageService#handle_fresh_start) and from the router's
  # AskContinueOrRestart tool, which are the same reading arriving by the two
  # paths a message can take.
  #
  # Both paths ask Conversation#unfinished_contribution? first, and neither
  # arrives here without it. A greeting with nothing half-written used to reach
  # this question too, where both answers were empty — "weitermachen" had
  # nothing to return to and ended at the menu anyway, "neu anfangen" had
  # nothing to discard (CON-2981). That greeting is now answered by
  # Flows::FreshStartAnswerService with what the citizen can start from.
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
  #
  # Running out of askings ends where the "start over" tap ends, not in the
  # cancellation message. It used to be CancelService, which told a citizen who
  # had only said hello three times that something was "abgebrochen" — the one
  # word that has to stay reserved for someone who asked for it (CON-2980).
  # The menu is also what breaks the loop: reset_flow! clears choice_reasks.
  #
  # The fixed menu rather than the assistant. Three messages the bot could not
  # read is the wrong moment to spend a completion on a fourth, and a
  # submission set aside earlier survives reset_flow! — so the menu offers it
  # back on a row, where cancelling used to throw it away.
  def ask
    return fixed_menu if @conversation.choice_reasks >= MAX_REASKS

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
  #
  # The parked flow first, because it is the only thing there is to carry on
  # with in that case. The question is asked whenever anything is unfinished,
  # and a submission set aside for a side trip counts
  # (Conversation#unfinished_contribution?) — so a citizen can be on a fresh
  # step holding nothing while their half-written contribution sits parked.
  # Restoring the interrupted step there would answer "weitermachen" with the
  # empty prompt they were already reading.
  def continue
    interrupted = @conversation.interrupted_step

    return Whatsapp::Flows::ParkedFlowService.resume(conversation: @conversation) if
      resume_parked_instead?

    return Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation) if
      interrupted.blank?

    @conversation.resume_interrupted_step!

    re_send_prompt(interrupted)
  end

  # Starting over is a beginning, so the reply is a beginning too: what the
  # citizen can start next, said by the assistant in its own words with its own
  # pills, rather than the cancellation message and its one button back to the
  # menu. A citizen who has just asked to begin should not have to read
  # "abgebrochen" and tap again to get anywhere, and should not have to read a
  # fixed list of three rows either. The typed "abbrechen" is still
  # CancelService, which is the ending this is not.
  #
  # The answer itself lives in Flows::FreshStartAnswerService, which the
  # greeting that never reaches this question shares: the discard is the only
  # part of it that belongs to the tap.
  def restart
    Whatsapp::Flows::FreshStartAnswerService.after_discard(conversation: @conversation)
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

    # A parked flow with nothing on the current step is the one case where
    # "carry on" means something other than the step the question interrupted.
    # Read from the conversation rather than passed in, because both readings
    # that ask the question already agreed there is unfinished work — this only
    # decides which of the two kinds it is.
    def resume_parked_instead?
      @conversation.parked_flow? && !@conversation.unsaved_submission?
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

    # The fixed list menu, for the question that ran out of askings (see #ask).
    # The other fallback — when the assistant cannot answer a beginning — lives
    # with the beginning it belongs to, in Flows::FreshStartAnswerService.
    def fixed_menu
      Whatsapp::Flows::MainMenuService.start_over(conversation: @conversation)
    end

    # The step's own question, from the one map three return paths share (see
    # StepPromptService). AWAITING_CONTINUE_DECISION cannot appear — the
    # question records the step it interrupted, never its own.
    def re_send_prompt(interrupted)
      Whatsapp::Flows::StepPromptService.call(conversation: @conversation, step: interrupted)
    end
end
