class Ai::Tools::WhatsappAiAssistant::StopMessages < Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

  description "Stops all WhatsApp messages to this citizen. Call it the moment they ask not to " \
              "be written to any more, however they phrase it — no more messages, leave me " \
              "alone, unsubscribe, take me off the list. Never argue and never tell them to " \
              "write STOPP instead: honouring this is not optional. The one exception is a " \
              "citizen in the middle of a contribution, a comment or a vote, whose \"stop\" may " \
              "mean only that: ask them once which they mean, and call this if they want no " \
              "more messages. It sends the confirmation itself, because leaving the channel must " \
              "work whether or not anything else does — so do not write one as well."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::IDLE
  end

  def execute
    return ask_first if mid_step_unasked?

    ::Whatsapp::Accounts::MessageDeliveryService.disable(conversation: conversation)

    halt("Turned off all messages for this citizen and confirmed it.")
  end

  private

    # A citizen part-way through a contribution is writing its text, and a proposal
    # about receiving fewer letters from the city reads exactly like asking to be
    # left alone. Acted on there it silenced the channel and dropped the draft, and
    # only a typed keyword reopened it — which nothing told them. A comment or a
    # vote in progress is the same question with a shorter answer: "stop" there
    # most likely means the comment or the vote.
    #
    # Asked once, then honoured. The question is read as it stood when the
    # citizen's message arrived, so the turn that asks it cannot answer it too.
    def mid_step_unasked?
      conversation.step_in_progress? && !conversation.stop_question_asked?
    end

    # Recorded here as well as at the keyword gate: "leave me alone" reaches this
    # tool without passing the keyword, and a question nobody wrote down is one the
    # next answer cannot settle.
    def ask_first
      conversation.ask_stop_question!

      { error: "This citizen is in the middle of a contribution, a comment or a vote, so this " \
               "may be about that rather than about this channel. Ask them once, in one short " \
               "question, whether they want to stop only this or receive no more messages at " \
               "all, and offer the cancel button for stopping only this. If they answer that " \
               "they want no more messages, call this again and it will stop them." }
    end
end
