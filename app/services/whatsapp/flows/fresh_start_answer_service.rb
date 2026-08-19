class Whatsapp::Flows::FreshStartAnswerService < Whatsapp::Flows::BaseService
  # The answer to a message with no substance of its own once it is settled that
  # nothing is being carried on: what the citizen can start from, said by the
  # assistant in its own words with its own pills, and the fixed list when it
  # cannot be.
  #
  # Extracted from Flows::ContinueOrRestartService#restart, which was the only
  # place that answered a beginning with prose. A greeting that no longer reaches
  # the question at all (CON-2981) is owed the same answer, and a second copy of
  # the routing, the fallback and the log would have drifted from it.
  #
  # Two entry points rather than one with a mode, because what has just happened
  # decides what the assistant may say: after_discard follows the "start over"
  # tap and must never offer back what it has just thrown away, nothing_unfinished
  # follows a greeting where there was nothing to throw away and nothing to
  # mention.
  def self.after_discard(conversation:)
    new(conversation: conversation).after_discard
  end

  def self.nothing_unfinished(conversation:)
    new(conversation: conversation).nothing_unfinished
  end

  # The discard runs first and unconditionally. It is the half of this the
  # citizen asked for, so it cannot wait on a model call that may time out or
  # come back empty — the flow is already reset by the time the router is asked
  # for a sentence.
  #
  # The fixed menu underneath is the "start over" one: its sentence belongs to a
  # tap inside a conversation already under way, not to a returning number.
  def after_discard
    abandoned_phase = phase_description

    @conversation.reset_flow!

    return if assistant_answered?(
      directive: start_over_directive(abandoned_phase), moment: :after_discard
    )

    Whatsapp::Flows::MainMenuService.start_over(conversation: @conversation)
  end

  # The reset costs the citizen nothing here — it is what "nothing unfinished"
  # means — and it is what keeps the answer honest: a citizen who has just been
  # offered the things they can start from must not have their next message
  # taken as the answer to the step they were silently still on.
  #
  # The greeting menu underneath rather than the "start over" one: nobody has
  # asked to begin again, they said hello.
  def nothing_unfinished
    phase = phase_description

    @conversation.reset_flow!

    return if assistant_answered?(
      directive: greeting_directive(phase), moment: :nothing_unfinished
    )

    Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation)
  end

  private

    # True only when the citizen has actually been sent something. A hand-off
    # sends nothing — the router hands the message back for the flow to answer —
    # so it counts as no reply here, the same as a failure. Named after
    # Inbound::AssistantRouting#router_answered?, which asks the same question of
    # the path this one is the exception to.
    #
    # This is the one place a tapped pill reaches the assistant.
    # Inbound::AssistantRouting refuses every tap on purpose (a pill already says
    # what it means, and a completion would only add latency), so the exception
    # lives in the flow that wants prose rather than as a hole in that rule.
    def assistant_answered?(directive:, moment:)
      return false if !::Ai::Settings.ai_available?
      return false if account.opt_out_at.present?

      result = route(directive)
      answered = result.success? && result.outcome != :flow

      log_outcome(answered: answered, moment: moment, result: result)

      answered
    end

    def route(directive)
      ::Whatsapp::AiAssistant::RouterService.call(
        conversation: @conversation, inbound_text: directive
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
        system_note,
        "The citizen tapped \"start over\" on the question whether to carry on or begin again. "\
        "Whatever they had unfinished is already discarded — never offer it back, never mention "\
        "it, and never say anything was cancelled.",
        phase_line(abandoned_phase),
        reply_instruction
      ].compact.join("\n")
    end

    # The same note for the greeting that never reached the question, with the
    # one thing the assistant must not be told twice: there is nothing to say
    # about work that was not there. A citizen who wrote "hallo" has not asked
    # for anything to be thrown away and must not read that anything was.
    def greeting_directive(phase)
      [
        system_note,
        "The citizen wrote something with no request of its own — a greeting, a question about "\
        "you, a request for the menu — and they had nothing half-written to carry on with. "\
        "Nothing was discarded and nothing was set aside: never say anything was cancelled and "\
        "never offer anything back.",
        phase_line(phase),
        reply_instruction
      ].compact.join("\n")
    end

    def system_note
      "[System note about what just happened. Not a message from the citizen: do not quote it, "\
        "do not answer it as text.]"
    end

    def reply_instruction
      "Answer with reply_with_actions: one short sentence that puts them at a beginning, and "\
        "the two or three actions that are the best next step from here. Do not call "\
        "show_main_menu — a reply of your own is the point."
    end

    def phase_line(phase)
      return if phase.blank?

      "They were taking part in #{phase}, which is the likeliest place they want to begin again."
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
    # nothing else in the log says so. The moment rides along rather than
    # splitting the pair of events, so one grep answers how often a beginning is
    # answered with prose whichever moment produced it.
    def log_outcome(answered:, moment:, result:)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: answered ? :fresh_start_routed : :fresh_start_fallback,
        conversation: @conversation,
        moment: moment,
        outcome: result.success? ? result.outcome : nil,
        error: result.success? ? nil : result.error
      )
    end
end
