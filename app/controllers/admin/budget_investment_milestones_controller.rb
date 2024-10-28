class Admin::BudgetInvestmentMilestonesController < Admin::MilestonesController
  private

    def milestoneable
      Budget::Investment.find(params[:budget_investment_id])
    end

    def milestoneable_path
      admin_polymorphic_path(@milestone.milestoneable, action: :milestones)
    end
end
