class PollAnswerDetailsQuery < ApplicationQuery
  def initialize(answer)
    @answer = answer
  end

  def participation
    ProjektPhaseStats::UserSegmentsQuery.call(Poll::Question::Answer::Stats.new(@answer))
  end

  def crossectional
    PollQuestionDetailsQuery.new(@answer.question).crossectional_for_answer(@answer)
  end
end
