class Evaluations::GeneratePhaseEvaluationJob < ApplicationJob
  queue_as :default

  def perform(projekt_phase_evaluation_id)
    row = ProjektPhaseEvaluation.find(projekt_phase_evaluation_id)

    Evaluations::GeneratePhaseEvaluation.call(row)
  end
end
