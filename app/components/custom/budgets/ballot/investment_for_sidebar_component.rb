require_dependency Rails.root.join("app", "components", "budgets", "ballot", "investment_for_sidebar_component").to_s

class Budgets::Ballot::InvestmentForSidebarComponent < Budgets::Ballot::InvestmentComponent
  delegate :current_user, to: :helpers

  private
    def delete_path
      budget_ballot_line_path(id: investment.id, investments_ids: investment_ids, budget_id: investment.budget.id)
    end

    def user_votes
      count = @investment.budget_ballot_lines.joins(:ballot).find_by(budget_ballots: { user_id: current_user.id }).line_weight
      tag.span t("custom.budgets.investments.index.sidebar.user_votes", count: count)
    end
end
