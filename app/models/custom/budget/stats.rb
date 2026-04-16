require_dependency Rails.root.join("app", "models", "budget", "stats").to_s

class Budget::Stats
  delegate :show_percentage_values_only?, to: :budget

  def headings
    groups = Hash.new(0)

    return groups if budget.heading.blank?

    groups[budget.heading.id] = Hash.new(0).merge(calculate_heading_totals(budget.heading))

    groups[:total] = Hash.new(0)
    groups[:total][:total_investments_count] = groups.sum { |_k, v| v[:total_investments_count] }
    groups[:total][:total_participants_support_phase] = groups.sum { |_k, v| v[:total_participants_support_phase] }
    groups[:total][:total_participants_vote_phase] = groups.sum { |_k, v| v[:total_participants_vote_phase] }
    groups[:total][:total_participants_every_phase] = groups.sum { |_k, v| v[:total_participants_every_phase] }

    groups[budget.heading.id].merge!(
      calculate_heading_stats_with_totals(
        groups[budget.heading.id], groups[:total], budget.heading.population
      )
    )

    groups[:total][:percentage_participants_support_phase] = groups.sum { |_k, v| v[:percentage_participants_support_phase] }
    groups[:total][:percentage_participants_vote_phase] = groups.sum { |_k, v| v[:percentage_participants_vote_phase] }
    groups[:total][:percentage_participants_every_phase] = groups.sum { |_k, v| v[:percentage_participants_every_phase] }

    groups
  end

  def total_votes
    Budget::Ballot::Line.joins(:ballot)
                        .where(budget_ballots: { budget_id: budget.id, conditional: false })
                        .sum(:line_weight)
  end

  private

    def support_phase_enabled?
      budget.phases.find_by(kind: "selecting")&.enabled? || false
    end

    def vote_phase_enabled?
      budget.phases.find_by(kind: "balloting")&.enabled? || false
    end
end
