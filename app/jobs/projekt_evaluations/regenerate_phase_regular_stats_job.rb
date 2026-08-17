class ProjektEvaluations::RegeneratePhaseRegularStatsJob < ApplicationJob
  queue_as :default

  def perform(projekt_phase_evaluation_id)
    row = ProjektPhaseEvaluation.find(projekt_phase_evaluation_id)

    ProjektEvaluations::GeneratePhaseEvaluation.regenerate_regular_stats(row)
  end
end
