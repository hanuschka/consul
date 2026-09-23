module AiAnalytics
  class StatQuestionRefresh < ApplicationJob
    queue_as :default
    self.max_run_time = Ai::Settings::JOB_MAX_RUN_TIME

    def perform(stat_question_id)
      stat_question = ::ProjektPhaseStatQuestion.find(stat_question_id)
      AiAnalytics::ProjektPhaseStatQuestion.call(stat_question)
    end
  end
end
