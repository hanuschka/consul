class Ai::Tools::WhatsappAiAssistant::StopMessages < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Stops all WhatsApp messages to this citizen. Call it the moment they ask not to " \
              "be written to any more, however they phrase it — no more messages, leave me " \
              "alone, unsubscribe, take me off the list. Never argue, never ask them to confirm " \
              "and never tell them to write STOPP instead: honouring this is not optional. " \
              "The one exception is a message that is part of a submission in progress, which " \
              "is the contribution's own text and not a request about this channel. " \
              "This sends the confirmation itself — do not write one as well."

  def execute
    return mid_submission_error if conversation.drafting?

    ::Whatsapp::Flows::MessageDeliveryService.disable(conversation: conversation)

    halt("Turned off all messages for this citizen.")
  end

  private

    # A citizen part-way through a submission is writing the contribution
    # itself, and a proposal about receiving fewer letters from the city reads
    # exactly like asking to be left alone. Acted on there it silenced the
    # channel and dropped the draft, and only a typed "Start" reopened it —
    # which nothing told them.
    #
    # Refusing here does not make leaving the channel harder. The typed keyword
    # is checked deterministically in Inbound::ProcessMessageService, before any
    # model is asked, so it still ends messages mid-submission and during an
    # outage; and a citizen who means it says so again once the submission is
    # over.
    def mid_submission_error
      { error: "This citizen is part-way through a submission, so this message is part of what " \
               "they are writing rather than a request about this channel. Call hand_to_flow " \
               "instead. If they truly want no more messages they can type STOPP, which is " \
               "handled outside this conversation." }
    end
end
