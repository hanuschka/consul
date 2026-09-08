# frozen_string_literal: true

class Polls::Questions::AnswerFormComponent < ApplicationComponent
  attr_reader :question_answer, :user_answer, :question
  delegate :can?, :current_user, :user_signed_in?, to: :helpers

  def initialize(question_answer:, user_answer: nil)
    @question_answer = question_answer
    @user_answer = user_answer
    @question = question_answer.question
  end

  def already_answered?
    user_answer.present?
  end

  def should_show_answer_weight?
    question.votation_type&.multiple_with_weight? &&
      question.max_votes.present?
  end

  # How much of a weighted question's budget this option may still be given, from
  # Polls::AnswerAllowanceQuery — the same reading the controller refuses a write
  # against, so the selector cannot offer a number the write would then reject.
  def available_vote_weight
    return 0 if current_user.blank?

    if !question.votation_type&.multiple_with_weight?
      raise "available_vote_weight called for a non multiple_with_weight question"
    end

    ::Polls::AnswerAllowanceQuery.remaining_weight(
      question: question, user: current_user, title: question_answer.title,
      recorded_answers: user_answers
    )
  end

  # Only asked of an option not yet chosen — an answered one renders the other
  # branch — so it is the same question as "may one more of these be recorded".
  # The citizen's rows travel with it: asked without them, a question would count
  # the same rows once per button on the page.
  def disable_answer?
    return false if current_user.blank?

    !::Polls::AnswerAllowanceQuery.call(
      question: question, user: current_user, title: question_answer.title,
      recorded_answers: user_answers
    )
  end

  def button_not_answered_class
    if question&.votation_type&.rating_scale?
      "rating-scale-button"
    else
      "button secondary hollow expanded"
    end
  end

  def button_answered_class
    if question&.votation_type&.rating_scale?
      "rating-scale-button rating-scale-button--answered"
    else
      "button answered expanded"
    end
  end

  private

    def user_answers
      @user_answers ||= helpers.poll_answers_by_question_for_current_user(question.poll)[question.id] || []
    end
end
