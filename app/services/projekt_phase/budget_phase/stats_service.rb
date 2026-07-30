class ProjektPhase::BudgetPhase::StatsService
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def stale?
    @projekt_phase.stats.empty?
  end

  def call
    @projekt_phase.update!(
      stats: counts.merge(demographics),
      stats_refreshed_at: Time.current
    )
  end

  private

    def counts
      {
        accepting_visible_proposals_count:    investments.count,
        accepting_proposal_authors_count:     accepting_author_ids.size,
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

        finished_winners_count: investments.winners.count
      }
    end

    def demographics
      combined = ProjektPhase::DemographicsCalculator.new(participant_ids)

      {
        participants_by_age:            combined.age_data,
        participants_by_geozone:        combined.geozone_data,
        individual_group_value_counts:  combined.individual_group_value_counts,
        **combined.gender_data
      }
        .merge(segment_demographics("accepting", accepting_participant_ids))
        .merge(segment_demographics("selecting", selecting_participant_ids))
        .merge(segment_demographics("balloting", balloting_participant_ids))
        .merge(segment_demographics("finished", finished_participant_ids))
    end

    def segment_demographics(prefix, ids)
      calculator = ProjektPhase::DemographicsCalculator.new(ids)

      {
        "#{prefix}_participants_by_age"           => calculator.age_data,
        "#{prefix}_participants_by_geozone"       => calculator.geozone_data,
        "#{prefix}_individual_group_value_counts" => calculator.individual_group_value_counts
      }.merge(calculator.gender_data.transform_keys { |key| "#{prefix}_#{key}" })
    end

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
        voter_type:   "User",
        conditional:  false
      )
    end

    def unique_supporters
      selecting_participant_ids.size
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

    def accepting_author_ids
      @accepting_author_ids ||=
        investments.select(:author_id).distinct.pluck(:author_id).compact
    end

    def accepting_participant_ids
      @accepting_participant_ids ||= begin
        commenter_ids = investment_comments.select(:user_id).distinct.pluck(:user_id)

        (accepting_author_ids + commenter_ids).uniq.compact
      end
    end

    def selecting_participant_ids
      @selecting_participant_ids ||=
        supports.select(:voter_id).distinct.pluck(:voter_id).uniq.compact
    end

    def balloting_participant_ids
      @balloting_participant_ids ||=
        budget.ballots.where(conditional: false).select(:user_id).distinct.pluck(:user_id).uniq.compact
    end

    def finished_participant_ids
      @finished_participant_ids ||=
        balloting_lines
          .where(investment_id: investments.winners.select(:id))
          .distinct
          .pluck("budget_ballots.user_id")
          .uniq.compact
    end

    def participant_ids
      @participant_ids ||=
        (accepting_participant_ids + selecting_participant_ids + balloting_participant_ids).uniq.compact
    end

    def balloting_lines
      @balloting_lines ||=
        Budget::Ballot::Line
          .joins(:ballot)
          .where(budget_ballots: { budget_id: budget.id, conditional: false })
    end

    def balloting_unique_voters
      balloting_participant_ids.size
    end
end
