module Whatsapp::BallotParticipation
  # Whether a citizen has already taken part in a vote, asked from the two places that
  # have to say so before anything is tapped — the projekt card and the list of open
  # votes — and answered by the same walk the ballot itself is asked over.
  #
  # Polls::BallotTraversalQuery#nothing_owed? is what decides it. Nothing here reads the
  # answers itself: a second reading of "has this citizen finished" is a second thing to
  # drift, and the one that drifts is the one a citizen sees on a button rather than the
  # one the ballot obeys.
  #
  # Which poll a phase carries is Polls::PhaseBallotQuery's answer and deliberately not
  # Whatsapp::VotableBallotQuery's, though that is the gate the ballot itself stands
  # behind. Having voted is a fact about the citizen and the poll, true whichever way
  # they cast it, and a chat that cannot ask a ballot can still say the citizen answered
  # it on the page. Going through the votability gate would also cost a full walk of
  # every question's shape per row, to establish something the mark does not depend on.
  #
  # What follows from that: a marked phase whose ballot the chat cannot ask answers a
  # tap with the ballot's address rather than with a sentence, which is what every tap
  # on such a phase has always answered with. The page is where the vote they cast is
  # legible anyway.

  module_function

  def completed?(projekt_phase:, user:)
    return false if user.blank?

    poll = ::Polls::PhaseBallotQuery.for(projekt_phase)

    return false if poll.blank?

    finished?(poll: poll, user: user)
  end

  # The same question asked of a card's phases at once, as the ids of the phases to
  # mark. Which poll each carries comes back in one query rather than one per row, the
  # way Whatsapp::ProjektCard.phase_facts already answers the rest of a card's rows.
  def completed_phase_ids(projekt_phases:, user:)
    return [] if user.blank?

    ballots = ::Polls::PhaseBallotQuery.by_phase(projekt_phases.map(&:id))

    return [] if ballots.blank?

    finished = completed_poll_ids(polls: ballots.values, user: user)

    ballots.filter_map { |projekt_phase_id, poll| projekt_phase_id if finished.include?(poll.id) }
  end

  # The same question asked of a page of polls at once. A traversal costs a fixed handful
  # of queries per poll, which is a handful too many repeated over ten rows of a list the
  # assistant asks for often — so the polls this citizen has never answered a question of
  # are dropped first, in one query, and only what is left is walked. That is nearly
  # always all of them: a citizen listing what is open has usually voted in none of it.
  def completed_poll_ids(polls:, user:)
    return [] if user.blank?

    begun = begun_poll_ids(polls, user)

    return [] if begun.empty?

    polls
      .select { |poll| begun.include?(poll.id) && finished?(poll: poll, user: user) }
      .map(&:id)
  end

  def finished?(poll:, user:)
    ::Polls::BallotTraversalQuery.for(poll: poll, user: user).nothing_owed?
  end

  # Every poll of the page this citizen has any answer recorded in. A map-point question
  # counts here like any other: what it records is Poll::Answer::MapPoint rows under an
  # answer row of its own, so the row exists even though its `answer` column stays null.
  def begun_poll_ids(polls, user)
    poll_ids = polls.map(&:id)

    return [] if poll_ids.blank?

    ::Poll::Answer
      .joins(:question)
      .where(author_id: user.id, poll_questions: { poll_id: poll_ids })
      .distinct
      .pluck("poll_questions.poll_id")
  end
end
