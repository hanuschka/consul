class AddShowBudgetSegmentsToProjektPhaseEvaluationVisibilities < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phase_evaluation_visibilities, :show_budget_segments, :boolean, default: true, null: false
  end
end
