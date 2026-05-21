class ProjektEvaluations::GenerateEvaluationJob < ApplicationJob
  queue_as :default

  def perform(projekt_id, selected_question_ids: [])
    projekt = Projekt.find(projekt_id)

    ProjektEvaluations::GenerateEvaluation.call(
      projekt,
      selected_question_ids: selected_question_ids
    )
  end
end
