class Budget::Investment::Stats < Budget::Stats
  alias_method :investment, :resource

  def phases
    %w[vote].select { |phase| send("#{phase}_phase_enabled?") }
  end

  def total_participants
    total_participants_vote_phase
  end

  def total_participants_vote_phase
    (balloters + poll_ballot_voters).uniq.count
  end

  private

    def participant_ids # changed
      participant_ids_vote_phase
    end

    def participant_ids_vote_phase
      (balloters + poll_ballot_voters).uniq
    end

    def balloters # changed
      @balloters ||= investment.budget_ballot_lines.where(conditional: false).joins(:ballot).pluck("budget_ballots.user_id").compact
    end

    def poll_ballot_voters
      @poll_ballot_voters ||= investment.budget.poll ? investment.budget.poll.voters.pluck(:user_id) : []
    end

    def vote_phase_enabled? # changed
      investment.budget.phases.find_by(kind: "balloting").enabled?
    end
end
