class AddShowHeatmapToProjektPhaseEvaluationVisibilities < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phase_evaluation_visibilities, :show_heatmap, :boolean, default: false, null: false
  end
end
