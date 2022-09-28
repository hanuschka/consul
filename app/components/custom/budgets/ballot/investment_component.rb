require_dependency Rails.root.join("app", "components", "budgets", "ballot", "investment_component").to_s

class Budgets::Ballot::InvestmentComponent < ApplicationComponent
  delegate :current_user, to: :helpers
  private

    def delete_path
      budget_ballot_line_path(id: investment.id, budget_id: investment.budget.id)
    end

  private
    def user_votes
      user = if params[:user_id].present?
        User.find(params[:user_id])
      else
        current_user
      end
      count = @investment.budget_ballot_lines.joins(:ballot).find_by(budget_ballots: { user_id: user.id }).line_weight
      tag.span t("custom.budgets.investments.index.sidebar.user_votes", count: count)
    end
end
