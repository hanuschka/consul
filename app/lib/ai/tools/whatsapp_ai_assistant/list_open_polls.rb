class Ai::Tools::WhatsappAiAssistant::ListOpenPolls < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the votes and surveys open right now, each with the projekt_phase_id that " \
              "starts it, whether it can be answered in the chat, the address of its ballot and " \
              "the date it closes. Name a project for its own, or pass null for the whole " \
              "portal. Where votable_in_chat is true, voting happens here: call start_poll_vote " \
              "with the projekt_phase_id rather than handing out the address, and offer that for " \
              "every row that can be. Where it is false the ballot_url is the way through — send " \
              "it with send_link. Returns facts for you to answer in your own words: it sends " \
              "nothing to the citizen itself. #{::Whatsapp::MAX_OFFERED_LIST_ROWS} at a time: " \
              "where there are more, say how many and offer more_action_id as a button."

  MORE_SCOPE = "polls".freeze

  params do
    optional :projekt_name,
      description: "The project name as the citizen wrote it, or null for the whole portal" do
      string
    end
    optional :from, description: FROM_DESCRIPTION do
      integer
    end
  end

  def execute(projekt_name: nil, from: 0)
    for_named_projekt(projekt_name) do |projekt|
      query = ::Whatsapp::OpenPollsQuery.new(projekt: projekt, from: from)
      polls = query.call
      votable_ids = ::Whatsapp::VotableBallotQuery.votable_poll_ids(polls)

      {
        polls: polls.map { |poll| row_for(poll, votable_ids) },
        **::Whatsapp::ListWindow.report(
          scope: MORE_SCOPE, from: from, shown: polls.size, total: query.total
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
    # The address is the row's own poll rather than its phase's, because the row
    # names that poll — on a phase that has somehow ended up with two, a link to the
    # other one would answer about a ballot nobody was shown.
    def row_for(poll, votable_ids)
      projekt_phase = poll.projekt_phase

      {
        title: poll.name,
        projekt_phase_id: projekt_phase.id,
        votable_in_chat: votable_ids.include?(poll.id),
        closes_on: ::Whatsapp::DatePhrase.absolute(poll.ends_at),
        closes_in: ::Whatsapp::DatePhrase.relative(poll.ends_at),
        projekt: projekt_title(projekt_phase.projekt),
        ballot_url: ::Whatsapp::ProjektLink.poll_ballot_url(poll)
      }.compact
    end
end
