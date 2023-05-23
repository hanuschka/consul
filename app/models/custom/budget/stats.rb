require_dependency Rails.root.join("app", "models", "budget", "stats").to_s

class Budget::Stats
  def total_votes
    if budget.distributed_voting?
      investments.pluck(:qualified_total_ballot_line_weight).sum
    else
      budget.ballots.pluck(:ballot_lines_count).sum
    end
  end
end
