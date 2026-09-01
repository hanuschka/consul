class Polls::Questions::AnswersComponent < ApplicationComponent
  attr_reader :question
  delegate :can?, :current_user, :user_signed_in?, to: :helpers

  def initialize(question)
    @question = question
  end

  def already_answered?(question_answer)
    user_answer(question_answer).present?
  end

  def question_answers
    question.question_answers
  end

  def user_answer(question_answer)
    user_answers_by_title[question_answer.title]
  end

  def disable_answer?(question_answer)
    question.multiple? && user_answers.size == question.max_votes
  end

  private

    def user_answers
      @user_answers ||= helpers.poll_answers_by_question_for_current_user(question.poll)[question.id] || []
    end

    def user_answers_by_title
      @user_answers_by_title ||= user_answers.index_by(&:answer)
    end
end
