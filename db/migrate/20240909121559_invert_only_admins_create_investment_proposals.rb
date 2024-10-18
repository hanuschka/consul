class InvertOnlyAdminsCreateInvestmentProposals < ActiveRecord::Migration[6.1]
  def up
    ProjektPhase::BudgetPhase.reset_column_information
    Budget.reset_column_information

    ProjektPhase::BudgetPhase.find_each do |phase|
      old_setting = phase.settings.find_by(key: "feature.general.only_admins_create_investment_proposals")
      phase.settings.find_or_create_by!(key: "feature.general.users_can_create_investment_proposals") do |setting|
        setting.value = old_setting.value == "" ? "active" : ""
      end
    end
  end

  def down
    ProjektPhase::BudgetPhase.find_each do |phase|
      new_setting = phase.settings.find_by(key: "feature.general.users_can_create_investment_proposals")
      phase.settings.find_or_create_by!(key: "feature.general.only_admins_create_investment_proposals") do |setting|
        setting.value = new_setting.value == "" ? "active" : ""
      end
    end
  end
end
