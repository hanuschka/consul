require_dependency Rails.root.join("app", "controllers", "polls", "questions_controller").to_s

class Polls::QuestionsController < ApplicationController
  include GuestUsers

  def answer
    @answer = @question.find_or_initialize_user_answer(current_user, params[:answer])
    @answer.answer_weight = params[:answer_weight].presence || 1
    @answer.save_and_record_voter_participation
    @question_answer = @question.question_answers.find(params[:question_answer_id])

    unless providing_an_open_answer?(@answer)
      @answer_updated = "answered"
    end

    respond_to do |format|
      format.js { render "polls/questions/answers" }
    end
  end

  def update_open_answer
    if open_answer_params[:open_answer_text].present?
      @answer = @question.find_or_initialize_user_answer(current_user, open_answer_params[:answer])
      @answer.save_and_record_voter_participation if @answer.new_record?

      if @answer.update(open_answer_text: open_answer_params[:open_answer_text])
        @open_answer_updated = true
      end
    else
      @answer = @question.answers.find_by(author: current_user, answer: open_answer_params[:answer])
      @answer.destroy_and_remove_voter_participation if @answer.present?
    end

    respond_to do |format|
      format.js { render "polls/questions/answers" }
    end
  end

  def wizard_step
    @question = Poll::Question.with_wizard_associations.find(@question.id)

    if !wizard_navigable?(@question)
      return head(:not_found)
    end

    if !@question.poll.projekt.visible_for?(current_user)
      return head(:forbidden)
    end

    render partial: "polls/wizard_item", layout: false, locals: { question: @question }
  end

  def csv_answers_streets
    question = Poll::Question.find(params[:id])

    respond_to do |format|
      format.csv do
        CsvJobs::PollQuestionAnswersStreetsExporterJob.perform_later(current_user.id, question.id)
      end
    end
  end

  def csv_answers_votes
    question = Poll::Question.find(params[:id])

    respond_to do |format|
      format.csv do
        send_data CsvServices::PollQuestionAnswersVotesExporter.new(question).call,
          filename: "question_#{question.id}_answers_votes_#{Time.zone.today.strftime("%d/%m/%Y")}.csv"
      end
    end
  end

  private

    def open_answer_params
      params.require(:poll_answer).permit(:answer, :open_answer_text)
    end

    def providing_an_open_answer?(answer)
      @question.open_question_answer.present? && @question.open_question_answer.title == answer.answer
    end

    def wizard_navigable?(question)
      question.parent_question_id.nil? && question.contextualize_by_poll_question_id.nil?
    end
end
