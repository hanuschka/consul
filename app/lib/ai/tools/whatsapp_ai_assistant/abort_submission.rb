class Ai::Tools::WhatsappAiAssistant::AbortSubmission < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Throws away the draft in progress, or the comment not yet posted, or leaves the " \
              "vote they are in the middle of. Call it the moment the citizen wants to " \
              "abandon what they are part-way through, however they phrase it — \"abbrechen\", " \
              "\"lass mal\", \"vergiss es\", \"ach doch nicht\". Declining one optional part is " \
              "not abandoning: no photo and no pin are answers to be gone on from, not reasons " \
              "to discard. Asking to go back to the very beginning is start_over, which asks " \
              "about the draft first. Asking for no more messages at all is stop_messages. A " \
              "wrong call here throws away everything they wrote and it cannot be recovered, so " \
              "when in doubt ask them first. What to say afterwards comes back with the result."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::IDLE
  end

  # The same reach as the cancel pill, which discards all three the same way: a
  # citizen who answers "only the comment" to the stop question in words has to
  # be able to leave it as surely as one who taps the pill.
  def execute
    return nothing_open_answer if !conversation.step_in_progress?

    # Read before the discard, which replaces the context the request lives in.
    starting_over = conversation.start_over_requested?
    discarded = ::Whatsapp::DiscardNotes.for(conversation)

    conversation.discard_draft!

    return start_over_answer if starting_over

    { discarded: true, hint: discarded }
  end

  private

    # The discard was the price of a request to go back to the beginning, made
    # before this turn and waiting on the citizen's yes — so this is not the end of
    # the exchange, and stopping at "it is gone" would leave them exactly where the
    # menu pill used to: nowhere, with nothing to tap. Every other abandonment gets
    # one way on (Whatsapp::DiscardNotes) rather than this whole fresh start, since
    # somebody who has just given up is not owed a list of what else there is.
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
