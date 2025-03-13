require_dependency Rails.root.join("app", "models", "budget", "stats").to_s

class Budget::Stats
  delegate :show_percentage_values_only?, to: :budget

  def total_votes
    Budget::Ballot::Line.joins(:ballot)
                        .where(budget_ballots: { budget_id: budget.id, conditional: false })
                        .sum(:line_weight)
  end

  private

    def support_phase_enabled?
      budget.phases.find_by(kind: "selecting").enabled?
    end

    def vote_phase_enabled?
      budget.phases.find_by(kind: "balloting").enabled?
    end
end
