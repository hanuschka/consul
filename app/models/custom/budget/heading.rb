require_dependency Rails.root.join("app", "models", "budget", "heading").to_s

class Budget
  class Heading < ApplicationRecord
    def total_ballot_votes
      investments.joins(budget_ballot_lines: :ballot).where(budget_ballots: { conditional: false }).sum("budget_ballot_lines.line_weight")
    end
  end
end
