class ProjektEvaluations::GeneratePhaseEvaluationJob < ApplicationJob
  queue_as :default
  self.max_run_time = Ai::Settings::JOB_MAX_RUN_TIME

  def perform(projekt_phase_evaluation_id)
    row = ProjektPhaseEvaluation.find(projekt_phase_evaluation_id)

    ProjektEvaluations::GeneratePhaseEvaluation.call(row)
  end
end
