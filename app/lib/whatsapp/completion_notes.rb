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
  # same rule whatever finished, and a copy per note is a copy to drift. Its second half
  # stands alone as well, for the one note whose citizen has already been told what
  # finished and must not be told it again.
  ONWARD = "offer what this citizen plausibly does next from where they now stand — what is " \
           "still open in the projekt they have just acted in, what they have already done in " \
           "this chat — and make it something to tap. Never a fixed set of exits, never the " \
           "wording you used the last time something finished here, and never an offer this " \
           "chat already shows them turning down: where they have waved a follow-up off, " \
           "confirm and leave it there. Where nothing is left open in that projekt, say so " \
           "plainly and leave what is running elsewhere as the way onward instead of inventing " \
           "a next step in it.".freeze

  CONTINUATION = "Confirm that in one line of your own and carry the conversation on from " \
                 "it rather than closing it off: #{ONWARD}".freeze

  # A finished ballot is confirmed with what was answered rather than in one line,
  # because asked a message at a time the answers have never been in front of the
  # citizen together. The answers keep the poll's wording for the reason the ballot
  # does: a summary in a paraphrase is a summary of something nobody answered.
  SUMMARY_CONTINUATION = "Confirm that with a short summary of these answers — each " \
                         "question cut to a few words, each answer in the poll's own " \
                         "wording as above — and carry the conversation on from it rather " \
                         "than closing it off: #{ONWARD}".freeze

  module_function

  # The poll is named because the citizen answered questions rather than "a vote", and
  # the phase it belongs to is what the state section of the prompt still points at: the
  # ballot's markers are dropped on completion but the projekt phase is not, so the
  # assistant knows where the citizen is standing.
  #
  # `answers` are Whatsapp::Polls::BallotSummaryQuery entries, listed for the summary
  # the citizen is confirmed with.
  def ballot_finished(poll:, answers:)
    finished = "The citizen has just answered the last question of the vote " \
               "\"#{poll.name}\" and every answer of theirs is recorded. There is nothing " \
               "left to ask them in it. They can still change their answers on the ballot " \
               "page until it closes."

    return "#{finished} #{CONTINUATION}" if answers.empty?

    "#{finished} Their answers, in the order they were asked:\n" \
      "#{answers.map { |entry| ballot_answer_line(entry) }.join("\n")}\n" \
      "#{SUMMARY_CONTINUATION}"
  end

  def ballot_answer_line(entry)
    answered =
      if entry.map_points.positive?
        "#{entry.map_points} place(s) marked on the map"
      else
        entry.answers.map { |answer| "\"#{answer}\"" }.join(", ")
      end

    "- \"#{entry.question.title}\": #{answered}"
  end

  # The vote is named the same way and for the same reason, but this is not a completion
  # at all — nothing happened just now. It says so plainly, because the note above and
  # this one differ in exactly the thing the citizen has to be told apart: whether their
  # answers were recorded a moment ago or some time before. A note that only said "every
  # answer of theirs is recorded" would be read as the first and confirmed as a fresh
  # ballot, which is the reading this exists to prevent.
  #
  # It used to add that they could not answer it a second time, which the model passed
  # on as "you cannot change your answers" — while the ballot page lets them change any
  # of them until the phase ends. What the chat will not do is ask it again.
  def ballot_already_answered(poll:)
    "The citizen has already taken part in the vote \"#{poll.name}\" — they answered it earlier, " \
      "not just now, and every answer of theirs from then still stands. It is not asked again " \
      "here. #{::Whatsapp::BallotAnswerRules.change_rule_for_poll(poll)} Say that they have " \
      "already voted and that their answers stand, and do not thank them for answers just " \
      "given. #{CONTINUATION}"
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

  # What the retry pill replays after a turn that did something and then could not write
  # its reply. Not the inbound that asked for it: that turn was never stored, so the
  # history has no trace of the tool call, and the same request put again would either
  # act a second time or be told there is nothing left to act on — "no comment has been
  # written down" about a comment the citizen can see on the page.
  #
  # What went through is not described here but handed over as the tools answered it —
  # the same results, hints included, that the model read in the turn that failed — so
  # there is no second account of each action to keep in step with the tools.
  #
  # Unlike every note above, the citizen has already been told what went through, by
  # the tool's own message or by the fallback line itself, so the confirmation is the
  # one thing this reply must not repeat.
  def retry_after_completed(completed_tool_results)
    answers = completed_tool_results
      .map { |entry| "#{entry["tool"]} answered #{JSON.generate(entry["result"])}" }
      .uniq
      .join("; ")

    "The citizen tapped \"try again\" after your last reply could not be sent. That turn had " \
      "already done something before it failed, and each tool's answer below is what you were " \
      "told at the time: #{answers}. They have already been sent whatever those answers say " \
      "was sent to them, and been told that it worked — do not say it again and do not call " \
      "any of those tools a second time. Carry the conversation on from there: #{ONWARD}"
  end
end
