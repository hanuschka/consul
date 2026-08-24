class Ai::Tools::WhatsappAiAssistant::AbortSubmission < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Throws away the draft in progress. Call it the moment the citizen wants to " \
              "abandon what they are part-way through, however they phrase it — \"abbrechen\", " \
              "\"lass mal\", \"vergiss es\", \"ach doch nicht\". Declining one optional part is " \
              "not abandoning: no photo and no pin are answers to be gone on from, not reasons " \
              "to discard. Asking for no more messages at all is stop_messages. A wrong call " \
              "here throws away everything they wrote and it cannot be recovered, so when in " \
              "doubt ask them first. Say afterwards, in one line, that it is discarded."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::IDLE
  end

  def execute
    return nothing_open_answer if !conversation.unsaved_submission?

    # Read before the discard, which replaces the context the request lives in.
    starting_over = conversation.start_over_requested?

    conversation.discard_draft!

    return start_over_answer if starting_over

    {
      discarded: true,
      hint: "Say in one line that it is gone and that they can start again whenever they like. " \
            "Do not list what else the portal offers unless they ask."
    }
  end

  private

    # The discard was the price of a request to go back to the beginning, made
    # before this turn and waiting on the citizen's yes — so this is not the end of
    # the exchange, and stopping at "it is gone" would leave them exactly where the
    # menu pill used to: nowhere, with nothing to tap. The line above deliberately
    # says the opposite for every other abandonment, where somebody who has just
    # given up is not owed a list of what else there is.
    def start_over_answer
      {
        discarded: true,
        started_over: true,
        hint: "Say in one line that it is gone, then give them the fresh start they asked " \
              "for: what is open to take part in right now, what they have already done, " \
              "what there is to read. Do not offer the projekt they have just left."
      }
    end

    def nothing_open_answer
      {
        discarded: false,
        hint: "There was nothing in progress to discard, so do not tell them anything was. " \
              "Answer what they actually asked."
      }
    end
end
