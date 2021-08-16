require_dependency Rails.root.join("app", "controllers", "polls", "questions_controller").to_s

class Polls::QuestionsController < ApplicationController

  def update_open_answer
    answer = Poll::Question::Answer.find_by(id: params[:answer_id])
    answer.update(open_answer_text: poll_question_answer_params[:open_answer_text])
    @answers_by_question_id = { @question.id => @question.answers.where(author: current_user).map { |answer| answer.answer } }
    render :answer
  end

  private

  def poll_question_answer_params
    params.require(:poll_question_answer).permit(:open_answer_text)
	end
end
