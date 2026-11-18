load Rails.root.join("app", "helpers", "budget_investments_helper.rb")

module BudgetInvestmentsHelper
  def default_active_investment_footer_tab?(tab)
    return true if tab == "comments" &&
      projekt_phase_feature?(@investment&.projekt_phase, "resource.show_comments")

    tab == "milestones" &&
      projekt_phase_feature?(@investment&.projekt_phase, "resource.enable_investment_milestones_tab") &&
      !projekt_phase_feature?(@investment&.projekt_phase, "resource.show_comments")
  end
end
