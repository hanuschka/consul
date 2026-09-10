module ResolvesSubmittedQuestionAnswer
  extend ActiveSupport::Concern

  private

    def submitted_question_answer
      return if @question.blank?

      @question.question_answers.find_by(id: params[:question_answer_id])
    end
end
