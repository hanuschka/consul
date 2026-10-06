module Whatsapp::StartOverNotes
  # What the assistant is told once the citizen has asked to go back to the start,
  # whether they tapped the pill that says so or wrote it in their own words. One
  # source for both, because a typed "von vorne" that meant something other than
  # the button was the bug: the model read it as licence to restart the draft in
  # hand, in the same projekt, and the citizen was put back inside it.
  #
  # Said rather than left to the cleared state, because the state is not the only
  # thing the model reads: the stored history is replayed every turn and still has
  # the projekt in it, so a nil phase on its own is one line of evidence against
  # ten. For a tap this note is the newest message in the turn, and for the typed
  # request it is the answer of the tool that acted on it — in both cases the last
  # thing read before the reply, which is the only place a correction outweighs
  # what came before it.
  WITHOUT_DRAFT = "The citizen asked to go back to the start. No projekt and no phase " \
                  "is selected any more, and nothing said earlier in this conversation " \
                  "about one carries into what follows: do not offer that projekt, its " \
                  "phases or a contribution to it unless they name it again themselves. " \
                  "Send them what applies right now — what is open to take part in, what " \
                  "they have already done, what there is to read — as a sentence or two " \
                  "with the options to tap, never as a numbered rundown of everything in " \
                  "the text. Answer it as if it were asked for the first time: never say " \
                  "that nothing has changed since an earlier overview, and never remark " \
                  "on having shown it before.".freeze

  WITH_DRAFT = "The citizen asked to go back to the start while part-way through a " \
               "contribution. Nothing has been discarded and the projekt is still selected, " \
               "because throwing away what they wrote cannot be taken back. Say in one line " \
               "what is unsaved, and ask whether to discard it or carry on with it. Call " \
               "abort_submission only if they say to discard.".freeze

  WITH_COMMENT = "The citizen asked to go back to the start while a comment they wrote is " \
                 "not posted yet. Nothing has been discarded and the projekt is still " \
                 "selected, because throwing away what they wrote cannot be taken back. Say " \
                 "in one line that their comment is not posted, and ask whether to discard " \
                 "it or carry on with it. Call abort_submission only if they say to " \
                 "discard.".freeze

  # One question for both, because one abort_submission discards both.
  WITH_DRAFT_AND_COMMENT = "The citizen asked to go back to the start while part-way " \
                           "through a contribution and with a comment they wrote not " \
                           "posted yet. Nothing has been discarded and the projekt is " \
                           "still selected, because throwing away what they wrote cannot " \
                           "be taken back. Name both in one line and ask once whether to " \
                           "discard them or carry on: discarding throws away both. Call " \
                           "abort_submission only if they say to discard.".freeze

  module_function

  def for(conversation)
    draft_unsaved = conversation.unsaved_submission?
    comment_unsaved = conversation.pending_comment.present?

    if draft_unsaved && comment_unsaved
      return WITH_DRAFT_AND_COMMENT
    end

    return WITH_DRAFT if draft_unsaved
    return WITH_COMMENT if comment_unsaved

    WITHOUT_DRAFT
  end
end
