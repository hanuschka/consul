class AddShowPollStatsToProjektPhaseEvaluationVisibilities < ActiveRecord::Migration[6.1]
  def up
    add_column :projekt_phase_evaluation_visibilities, :show_poll_stats,
      :boolean, default: false, null: false

    execute <<~SQL
      UPDATE projekt_phase_evaluation_visibilities
      SET show_poll_stats = true
      WHERE show_kpis = true OR show_questions = true OR show_open_responses = true
    SQL
  end

  def down
    remove_column :projekt_phase_evaluation_visibilities, :show_poll_stats
  end
end
