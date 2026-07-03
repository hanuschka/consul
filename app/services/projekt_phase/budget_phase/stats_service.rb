class ProjektPhase::BudgetPhase::StatsService
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def stale?
    @projekt_phase.stats.empty?
  end

  def call
    demographics = ProjektPhase::DemographicsCalculator.new(participant_ids)

    @projekt_phase.update!(
      stats: {
        accepting_visible_proposals_count:    investments.count,
        accepting_proposal_authors_count:     investments.select(:author_id).distinct.count,
        accepting_comments_count:             accepting_comments_count,
        accepting_reported_proposals_count:   investments.where("flags_count > 0").count,

        reviewing_pending_proposals_count:    investments.undecided.count,
        reviewing_approved_proposals_count:   investments.feasible.count,
        reviewing_rejected_proposals_count:   investments.unfeasible.count,

        selecting_unique_supporters_count:    unique_supporters,
        selecting_online_votes_count:         online_votes,
        selecting_offline_votes_count:        offline_votes,
        selecting_total_votes_count:          online_votes + offline_votes,

        publishing_prices_selected_proposals_count:     investments.selected.count,
        publishing_prices_not_selected_proposals_count: investments.feasible.where(selected: false).count,

        balloting_unique_voters_count:      balloting_unique_voters,
        balloting_total_votes_count:        balloting_lines.count,
        balloting_weighted_votes_total:     balloting_lines.sum(:line_weight),
        balloting_weighted_votes_online:    balloting_lines.merge(Budget::Ballot.where(physical: false)).sum(:line_weight),
        balloting_weighted_votes_offline:   balloting_lines.merge(Budget::Ballot.where(physical: true)).sum(:line_weight),

        finished_winners_count: investments.winners.count,

        participants_by_age:            demographics.age_data,
        participants_by_geozone:        demographics.geozone_data,
        individual_group_value_counts:  individual_group_value_counts,
        **demographics.gender_data
      },
      stats_refreshed_at: Time.current
    )
  end

  private

    def budget
      @budget ||= @projekt_phase.budget
    end

    def investments
      @investments ||= budget.investments
    end

    def supports
      @supports ||= ActsAsVotable::Vote.where(
        votable_type: "Budget::Investment",
        votable_id:   investments.select(:id),
        voter_type:   "User"
      )
    end

    def unique_supporters
      supports.select(:voter_id).distinct.count
    end

    def online_votes
      @online_votes ||= supports.count
    end

    def offline_votes
      @offline_votes ||= investments.sum(:physical_votes)
    end

    def investment_comments
      @investment_comments ||= Comment.where(
        commentable_type: "Budget::Investment",
        commentable_id:   investments.select(:id),
        valuation:        false,
        hidden_at:        nil
      )
    end

    def accepting_comments_count
      investment_comments.count
    end

    def participant_ids
      @participant_ids ||= begin
        author_ids = investments.select(:author_id).distinct.pluck(:author_id)
        voter_ids = supports.select(:voter_id).distinct.pluck(:voter_id)
        ballot_voter_ids = budget.ballots.where(conditional: false).select(:user_id).distinct.pluck(:user_id)
        commenter_ids = investment_comments.select(:user_id).distinct.pluck(:user_id)

        (author_ids + voter_ids + ballot_voter_ids + commenter_ids).uniq.compact
      end
    end

    def individual_group_value_counts
      return {} if participant_ids.empty?

      UserIndividualGroupValue
        .joins(individual_group_value: :individual_group)
        .where(user_id: participant_ids, individual_groups: { kind: "soft" })
        .group(:individual_group_value_id)
        .count
    end

    def balloting_lines
      @balloting_lines ||=
        Budget::Ballot::Line
          .joins(:ballot)
          .where(budget_ballots: { budget_id: budget.id, conditional: false })
    end

    def balloting_unique_voters
      budget.ballots.where(conditional: false).select(:user_id).distinct.count
    end
end
