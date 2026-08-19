class Ai::Tools::WhatsappAiAssistant::StopMessages < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Stops all WhatsApp messages to this citizen. Call it the moment they ask not to " \
              "be written to any more, however they phrase it — no more messages, leave me " \
              "alone, unsubscribe, take me off the list. Never argue, never ask them to confirm " \
              "and never tell them to write STOPP instead: honouring this is not optional. The " \
              "one exception is a message that is part of a contribution they are writing, which " \
              "is its text and not a request about this channel. It sends the confirmation " \
              "itself, because leaving the channel must work whether or not anything else does — " \
              "so do not write one as well."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::IDLE
  end

  def execute
    return mid_submission_error if conversation.unsaved_submission?

    ::Whatsapp::Accounts::MessageDeliveryService.disable(conversation: conversation)

    halt("Turned off all messages for this citizen and confirmed it.")
  end

  private

    # A citizen part-way through a contribution is writing its text, and a proposal
    # about receiving fewer letters from the city reads exactly like asking to be
    # left alone. Acted on there it silenced the channel and dropped the draft, and
    # only a typed keyword reopened it — which nothing told them.
    def mid_submission_error
      { error: "This citizen is part-way through a contribution, so this message is more likely " \
               "part of what they are writing than a request about this channel. Ask them which " \
               "they meant. If they truly want no more messages, typing STOPP is honoured " \
               "outside this conversation whatever happens here." }
    end
end
