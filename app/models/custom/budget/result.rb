load Rails.root.join("app", "models", "budget", "result.rb")

class Budget
  class Result
    def investments
      scope = heading.investments.selected
      scope = scope.where.not(price: nil) if budget.show_money?

      if budget.distributed_voting?
        scope.sort_by_ballot_line_weight
      else
        scope.sort_by_ballots
      end
    end

    def score(investment)
      if budget.distributed_voting?
        line_weights.fetch(investment.id, 0)
      else
        investment.ballot_lines_count
      end
    end

    private

      def line_weights
        @line_weights ||= Budget::Ballot::Line.joins(:ballot)
                                              .where(budget_ballots: { conditional: false })
                                              .where(investment_id: heading.investments.select(:id))
                                              .group(:investment_id)
                                              .sum(:line_weight)
      end
  end
end
