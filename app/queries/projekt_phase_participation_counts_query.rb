# Participation per projekt phase, read by demokratie.today to rank its
# projekt overview. Only what the public sees is counted: published, accepted
# and not retired proposals, voters of published live polls, and investments
# that are not hidden.
class ProjektPhaseParticipationCountsQuery < ApplicationQuery
  def initialize(projekt_phase_ids)
    @projekt_phase_ids = projekt_phase_ids
  end

  def call
    {
      comment: comment_counts,
      proposal: proposal_counts,
      voting: voting_counts,
      budget: budget_counts
    }
  end

  private

    def comment_counts
      ProjektPhase::CommentPhase
        .where(id: @projekt_phase_ids)
        .where("comments_count > 0")
        .pluck(:id, :comments_count)
        .to_h
    end

    def proposal_counts
      Proposal
        .published
        .not_retired
        .admin_accepted
        .where(projekt_phase_id: @projekt_phase_ids)
        .group(:projekt_phase_id)
        .count
    end

    # The same people often answer several polls of one phase, so adding polls
    # up would count them more than once. A phase counts as much as its best
    # attended poll.
    def voting_counts
      phase_ids_by_poll_id =
        Poll
          .published
          .where(live: true, projekt_phase_id: @projekt_phase_ids)
          .pluck(:id, :projekt_phase_id)
          .to_h
      voters_by_poll_id = Poll::Voter.where(poll_id: phase_ids_by_poll_id.keys).group(:poll_id).count

      voters_by_poll_id.each_with_object({}) do |(poll_id, voters_count), counts|
        phase_id = phase_ids_by_poll_id[poll_id]
        counts[phase_id] = [counts[phase_id].to_i, voters_count].max
      end
    end

    # Consul has no participant number for a budget. Submitted investments plus
    # the votes cast on them rank budgets by activity instead.
    def budget_counts
      investment_totals =
        investments
          .group("budgets.projekt_phase_id")
          .sum(
            Arel.sql(
              "1 + COALESCE(budget_investments.physical_votes, 0) " \
              "+ COALESCE(budget_investments.ballot_lines_count, 0)"
            )
          )
      online_votes =
        investments
          .joins(:votes_for)
          .where(votes: { conditional: false })
          .group("budgets.projekt_phase_id")
          .sum(Arel.sql("COALESCE(votes.vote_weight, 0)"))

      investment_totals.merge(online_votes) { |_phase_id, total, votes| total + votes }
    end

    def investments
      Budget::Investment
        .joins(:budget)
        .where(budgets: { projekt_phase_id: @projekt_phase_ids })
    end
end
