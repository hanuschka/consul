class Ai::Tools::WhatsappAiAssistant::ListOpenPolls < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the votes and surveys open right now, each with the projekt_phase_id that " \
              "starts it, whether it can be answered in the chat, the address of its ballot and " \
              "the date it closes. Name a project for its own, or pass null for the whole " \
              "portal. Where votable_in_chat is true, voting happens here: call start_poll_vote " \
              "with the projekt_phase_id rather than handing out the address, and offer that for " \
              "every row that can be. Where it is false the ballot_url is the way through — send " \
              "it with send_link. counts gives, for every open vote and not only the rows " \
              "shown, how many this citizen answered in full, how many they began and left " \
              "part-way, and how many they have not answered at all — take any number you say " \
              "from counts, never by counting rows. Rows come partly answered first, then not " \
              "answered, then answered. A row marked already_voted was answered in full " \
              "earlier: say so where you name it and do not offer to start it — it is not " \
              "asked again here, but until it closes they can change their answers on its " \
              "ballot_url, so offer that link when they want to change something. A row " \
              "marked partly_answered keeps the answers given; start_poll_vote picks it up at " \
              "the first question still open. A vote that is not in the list is simply not " \
              "open — never tell the citizen they took part in something the list does not " \
              "mark. covers says what counts: 'projekt' when a project was named, 'portal' " \
              "for the whole portal — say which when you name a number. " \
              "Returns facts for you to answer in your own words: it sends nothing to the " \
              "citizen itself. #{::Whatsapp::MAX_OFFERED_LIST_ROWS} at a time: where there " \
              "are more, say how many and offer more_action_id as a button."

  MORE_SCOPE = "polls".freeze

  # What the count covers, said in the result rather than left to the model to
  # remember from its own arguments: the same total read as a portal's and as one
  # projekt's is the difference between "four votes are running here" and "four
  # votes are running", and the citizen hears only the sentence.
  PROJEKT_COVERAGE = "projekt".freeze
  PORTAL_COVERAGE = "portal".freeze

  params do
    optional :projekt_name,
      description: "The project name as the citizen wrote it, or null for the whole portal" do
      string
    end
    optional :from, description: FROM_DESCRIPTION do
      integer
    end
  end

  # Partly answered first, because those hold answers already given and a question
  # still owed; then the ones not begun; the ones answered in full last.
  STATE_ORDER = {
    ::Whatsapp::BallotParticipation::PARTLY_ANSWERED => 0,
    nil => 1,
    ::Whatsapp::BallotParticipation::ANSWERED => 2
  }.freeze

  # Where the citizen stands is read over every open poll rather than over the page
  # on screen, and the page is cut from that ordering afterwards. Read off the page,
  # the same twenty-two open votes with eight answered came out as "fourteen still
  # missing" in one reply and as "two of the ones shown" in the next.
  def execute(projekt_name: nil, from: 0)
    for_named_projekt(projekt_name) do |projekt|
      all_polls = ::Whatsapp::OpenPollsQuery.new(projekt: projekt).all
      states = ::Whatsapp::BallotParticipation.states_by_poll_id(
        polls: all_polls, user: conversation.user
      )
      page = ::Whatsapp::ListWindow.page(ordered(all_polls, states), from: from)
      votable_ids = ::Whatsapp::VotableBallotQuery.votable_poll_ids(page)

      {
        covers: projekt.present? ? PROJEKT_COVERAGE : PORTAL_COVERAGE,
        counts: counts_of(all_polls, states),
        polls: page.map { |poll| row_for(poll, votable_ids, states) },
        **::Whatsapp::ListWindow.report(
          scope: MORE_SCOPE, from: from, shown: page.size, total: all_polls.size
        )
      }
    end
  end

  private

    # The phase's id travels beside the poll because it is the phase, not the poll,
    # that start_poll_vote takes: a voting phase carries exactly one ballot and every
    # rule about who may answer it — the dates, the districts, the age — belongs to
    # the phase.
    #
    # Whether the chat can ask it is answered per row rather than left to the model to
    # infer, because the answer is a whole traversal of the poll's questions and
    # nothing in a row's other fields hints at it. The set arrives ready-made:
    # Whatsapp::VotableBallotQuery.votable_poll_ids answers the whole page for what
    # asking one poll costs, where asking row by row paid it nine times over.
    #
    # Whether the citizen has taken part travels only where it is true: a false on every
    # row of a list nobody has voted in is the one fact repeated ten times, and #compact
    # drops it.
    #
    # The address is the row's own poll rather than its phase's, because the row
    # names that poll — on a phase that has somehow ended up with two, a link to the
    # other one would answer about a ballot nobody was shown.
    def row_for(poll, votable_ids, states)
      projekt_phase = poll.projekt_phase
      state = states[poll.id]

      {
        title: poll.name,
        projekt_phase_id: projekt_phase.id,
        votable_in_chat: votable_ids.include?(poll.id),
        already_voted: (true if state == ::Whatsapp::BallotParticipation::ANSWERED),
        partly_answered: (true if state == ::Whatsapp::BallotParticipation::PARTLY_ANSWERED),
        closes_on: ::Whatsapp::DatePhrase.absolute(poll.ends_at),
        closes_in: ::Whatsapp::DatePhrase.relative(poll.ends_at),
        projekt: projekt_title(projekt_phase.projekt),
        ballot_url: ::Whatsapp::ProjektLink.poll_ballot_url(poll)
      }.compact
    end

    # Deterministic to the id, because a page is cut from this order and the next page
    # from the same order again: two polls tied on everything else would otherwise swap
    # between the two calls and one of them be shown twice.
    def ordered(polls, states)
      polls.sort_by do |poll|
        [
          STATE_ORDER.fetch(states[poll.id]),
          poll.ends_at.present? ? 0 : 1,
          poll.ends_at.to_i,
          poll.id
        ]
      end
    end

    def counts_of(polls, states)
      state_values = states.values

      {
        total: polls.size,
        answered_in_full: state_values.count(::Whatsapp::BallotParticipation::ANSWERED),
        partly_answered: state_values.count(::Whatsapp::BallotParticipation::PARTLY_ANSWERED),
        not_answered: polls.size - states.size
      }
    end
end
