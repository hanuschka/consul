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
  def continue
    interrupted = @conversation.interrupted_step

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
  # The discard runs first and unconditionally. It is the half of this the
  # citizen asked for, so it cannot wait on a model call that may time out or
  # come back empty — reset_flow! has already happened by the time the router
  # is asked for a sentence.
  #
  # This is the one tapped pill that reaches the assistant.
  # Inbound::AssistantRouting refuses every tap on purpose (a pill already says
  # what it means, and a completion would only add latency), so the exception
  # lives here, in the flow that wants prose, rather than as a hole in that
  # rule.
  def restart
    abandoned_phase = phase_description

    @conversation.reset_flow!

    return if assistant_answered?(abandoned_phase)

    fixed_menu
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

    # The fixed list menu. The answer whenever the assistant cannot be the one
    # to give it — AI switched off for the portal, a number that has opted out,
    # a router turn that failed or that answered with nothing — and the answer
    # when the question itself ran out of askings. It resets the flow on the
    # way, which on the restart path is the second reset: one idle write, and
    # the fallback stays correct on its own rather than depending on what ran
    # before it.
    def fixed_menu
      Whatsapp::Flows::MainMenuService.start_over(conversation: @conversation)
    end

    # True only when the citizen has actually been sent something. A hand-off
    # sends nothing — the router hands the message back for the flow to answer —
    # so it counts as no reply here, the same as a failure. Named after
    # Inbound::AssistantRouting#router_answered?, which asks the same question
    # of the path this one is the exception to.
    def assistant_answered?(abandoned_phase)
      return false if !::Ai::Settings.ai_available?
      return false if account.opt_out_at.present?

      result = route(abandoned_phase)
      answered = result.success? && result.outcome != :flow

      log_outcome(answered: answered, result: result)

      answered
    end

    def route(abandoned_phase)
      ::Whatsapp::AiAssistant::RouterService.call(
        conversation: @conversation, inbound_text: start_over_directive(abandoned_phase)
      )
    end

    # Not the citizen's words: they tapped a pill, and the router only takes
    # text. Written as a note about what happened rather than as something they
    # said, because a bare "neu anfangen" is a message with no substance of its
    # own — which the routing rules answer with show_main_menu, the fixed list
    # this exists to replace.
    #
    # The phase they were in is named because reset_flow! has just dropped it:
    # "start over" usually means start over here, and without the line the
    # assistant would be offering the whole portal to someone who had already
    # chosen a corner of it.
    def start_over_directive(abandoned_phase)
      [
        "[System note about what just happened. Not a message from the citizen: do not quote it, "\
        "do not answer it as text.]",
        "The citizen tapped \"start over\" on the question whether to carry on or begin again. "\
        "Whatever they had unfinished is already discarded — never offer it back, never mention "\
        "it, and never say anything was cancelled.",
        abandoned_phase_line(abandoned_phase),
        "Answer with reply_with_actions: one short sentence that puts them at a beginning, and "\
        "the two or three actions that are the best next step from here. Do not call "\
        "show_main_menu — a reply of your own is the point."
      ].compact.join("\n")
    end

    def abandoned_phase_line(abandoned_phase)
      return if abandoned_phase.blank?

      "They were taking part in #{abandoned_phase}, which is the likeliest place they want to "\
        "begin again."
    end

    # Read before the reset, because reset_flow! nils the phase. Blank for a
    # citizen who had not got as far as choosing one.
    def phase_description
      projekt_phase = @conversation.projekt_phase

      return if projekt_phase.blank?

      "#{::Whatsapp::ProjektLink.title(projekt_phase.projekt)} — #{projekt_phase.title}"
    end

    # A fallback is not a failure worth reporting, but it is worth counting: the
    # menu going out instead of a sentence is the feature not happening, and
    # nothing else in the log says so.
    def log_outcome(answered:, result:)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: answered ? :start_over_routed : :start_over_fallback,
        conversation: @conversation,
        outcome: result.success? ? result.outcome : nil,
        error: result.success? ? nil : result.error
      )
    end

    # The step's own question, from the one map three return paths share (see
    # StepPromptService). AWAITING_CONTINUE_DECISION cannot appear — the
    # question records the step it interrupted, never its own.
    def re_send_prompt(interrupted)
      Whatsapp::Flows::StepPromptService.call(conversation: @conversation, step: interrupted)
    end
end
