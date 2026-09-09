module Whatsapp::CompletionNotes
  # What the assistant is told when something in the chat has just finished. These read
  # like the tap notes in Whatsapp::Inbound::ProcessMessageService: one line of fact in
  # the third person, handed in as the newest message of a turn. They are not sentences
  # for the citizen and they prescribe no wording.
  #
  # A completed action used to end the chat. A vote counted or an account linked arrived
  # as one fixed line with nothing under it to tap, which reads as the bot being finished
  # with the citizen rather than with the action. What the assistant does with the fact
  # below is decide where the conversation goes from there, out of the same state and the
  # same tools it answers everything else with — so what is offered follows the projekt
  # actually acted in rather than a fixed set of exits.
  #
  # The rule is one string shared by every note rather than written into each. It is the
  # same rule whatever finished, and a copy per note is a copy to drift.
  CONTINUATION = "Confirm that in one line of your own and carry the conversation on from " \
                 "it rather than closing it off: offer what this citizen plausibly does next " \
                 "from where they now stand — what is still open in the projekt they have just " \
                 "acted in, what they have already done in this chat — and make it something " \
                 "to tap. Never a fixed set of exits, never the wording you used the last time " \
                 "something finished here, and never an offer this chat already shows them " \
                 "turning down: where they have waved a follow-up off, confirm and leave it " \
                 "there. Where nothing is left open in that projekt, say so plainly and leave " \
                 "what is running elsewhere as the way onward instead of inventing a next step " \
                 "in it.".freeze

  module_function

  # The poll is named because the citizen answered questions rather than "a vote", and
  # the phase it belongs to is what the state section of the prompt still points at: the
  # ballot's markers are dropped on completion but the projekt phase is not, so the
  # assistant knows where the citizen is standing.
  def ballot_finished(poll:)
    "The citizen has just answered the last question of the vote \"#{poll.name}\" and every " \
      "answer of theirs is recorded. There is nothing left to ask them in it. #{CONTINUATION}"
  end

  # The vote is named the same way and for the same reason, but this is not a completion
  # at all — nothing happened just now. It says so plainly, because the note above and
  # this one differ in exactly the thing the citizen has to be told apart: whether their
  # answers were recorded a moment ago or some time before. A note that only said "every
  # answer of theirs is recorded" would be read as the first and confirmed as a fresh
  # ballot, which is the reading this exists to prevent.
  def ballot_already_answered(poll:)
    "The citizen has already taken part in the vote \"#{poll.name}\" — they answered it earlier, " \
      "not just now, and every answer of theirs from then still stands. There is nothing left to " \
      "ask them in it and they cannot answer it a second time. Say that they have already voted " \
      "and that their answers stand, and do not thank them for answers just given. #{CONTINUATION}"
  end

  # Linking is the one completion that interrupted something else. What that something
  # was is in the replayed history above rather than in this note — it is whatever they
  # were doing when the login link got in the way — so the note says to read it there
  # instead of asking the citizen to say it again.
  def account_linked
    "The citizen has just followed their login link on the portal and their account is now " \
      "linked to this number, so everything that needs an account is open to them from here " \
      "on. Whatever they were trying to do when the linking interrupted them is above in this " \
      "chat: pick that up rather than asking what they would like to do. #{CONTINUATION}"
  end
end
