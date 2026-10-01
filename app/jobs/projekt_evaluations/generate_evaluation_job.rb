class ProjektEvaluations::GenerateEvaluationJob < ApplicationJob
  queue_as :default
  self.max_run_time = Ai::Settings::JOB_MAX_RUN_TIME

  def perform(projekt_id, selected_question_ids: [])
    projekt = Projekt.find(projekt_id)

    ProjektEvaluations::GenerateEvaluation.call(
      projekt,
      selected_question_ids: selected_question_ids
    )
  end
end
