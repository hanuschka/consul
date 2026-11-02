load Rails.root.join("app", "components", "budgets", "ballot", "investment_for_sidebar_component.rb")

class Budgets::Ballot::InvestmentForSidebarComponent < Budgets::Ballot::InvestmentComponent

  private
    def delete_path
      budget_ballot_line_path(id: investment.id, investments_ids: investment_ids, budget_id: investment.budget.id)
    end
end
