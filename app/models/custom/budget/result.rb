load Rails.root.join("app", "models", "budget", "result.rb")

class Budget
  class Result
    def investments
      if budget.distributed_voting?
        heading.investments.selected.sort_by_ballot_line_weight
      else
        heading.investments.selected.sort_by_ballots
      end
    end
  end
end
