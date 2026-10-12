class Ai::Tools::WhatsappAiAssistant::AbortSubmission < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Throws away the draft in progress, or the comment not yet posted, or leaves the " \
              "vote they are in the middle of. Call it the moment the citizen wants to " \
              "abandon what they are part-way through, however they phrase it — \"abbrechen\", " \
              "\"lass mal\", \"vergiss es\", \"ach doch nicht\". Declining one optional part is " \
              "not abandoning: no photo and no pin are answers to be gone on from, not reasons " \
              "to discard. Asking to go back to the very beginning is start_over, which asks " \
              "about the draft or the comment first. Asking for no more messages at all is " \
              "stop_messages. While " \
              "they are changing a comment or a draft they had already seen, it drops only that " \
              "change and brings back the version they read; called again, it discards the " \
              "rest. A wrong call here throws away everything they wrote and it cannot be " \
              "recovered, so when in doubt ask them first. What to say afterwards comes back " \
              "with the result."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::IDLE
  end

  # The same reach as the cancel pill, which discards all three the same way: a
  # citizen who answers "only the comment" to the stop question in words has to
  # be able to leave it as surely as one who taps the pill. That includes the
  # pill's narrower reach while a change is open: "Änderung verwerfen" typed out
  # takes back the change, as the tap does, rather than the whole comment.
  #
  # Not while a start-over waits on this call, though: the yes it answers was to
  # losing the whole draft or comment on the way back to the beginning.
  def execute
    return nothing_open_answer if !conversation.step_in_progress?

    # Read before the discard, which replaces the context the request lives in.
    starting_over = conversation.start_over_requested?

    if !starting_over && conversation.revision_open?
      return revert_answer
    end

    discarded = ::Whatsapp::DiscardNotes.for(conversation)

    conversation.discard_draft!

    return start_over_answer if starting_over

    { discarded: true, hint: discarded }
  end

  private

    # Words are less exact than the pill, so the whole of what they wrote may have
    # been meant. Said rather than guessed at: the change is the smaller loss to have
    # dropped by mistake, and calling this again with it gone discards the rest.
    def revert_answer
      # Read before the revert, which closes the change it describes.
      kind = conversation.revision_kind
      reverted = ::Whatsapp::RevertNotes.for(conversation)

      conversation.revert_revision!

      {
        discarded: false,
        change_dropped: true,
        hint: "#{reverted} Where their words clearly meant the whole #{kind} rather than the " \
              "change, call abort_submission again now instead of showing it: with the change " \
              "dropped, it discards the rest."
      }
    end

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
