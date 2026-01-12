module AiAnalytics
  class StatQuestionRefresh < ApplicationJob
    queue_as :default

    def perform(stat_question_id)
      stat_question = ProjektPhaseStatQuestion.find(stat_question_id)
      AiAnalytics::ProjektPhaseStatQuestion.call(stat_question)
    end
  end
end
