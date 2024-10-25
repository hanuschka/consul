class MoveShowRelativeBallottingResultsToBudgets < ActiveRecord::Migration[6.1]
  def up
    add_column :budgets, :show_percentage_values_only, :boolean, default: false

    Budget.reset_column_information
    ProjektPhase.reset_column_information

    Budget.find_each do |budget|
      next unless budget.projekt_phase.present?

      setting_value = budget.projekt_phase.settings
        .find_by(key: "feature.general.show_relative_ballotting_results")&.value
      budget.update!(show_percentage_values_only: setting_value.present?)
    end
  end

  def down
    remove_column :budgets, :show_percentage_values_only
  end
end
