# frozen_string_literal: true

class Polls::Questions::OpenAnswerComponent < ApplicationComponent
  attr_reader :question
  delegate :can?, :current_user, to: :helpers

  def initialize(question)
    @question = question
  end

  def render?
    question.open_question_answer.present? && question.can_accept_open_answer?
  end

  def can_answer?
    can?(:answer, question) &&
      question.open_question_answer.present? &&
      (user_answers.include?(open_answer) || any_remaining_votes?)
  end

  def open_answer
    @open_answer ||= question.answers.find_or_initialize_by(author: current_user, answer: question.open_question_answer.title)
  end

  def additional_form_class
    classes = []

    classes << "js-question-answered" if open_answer.open_answer_text.present?
    classes << "column medium-4 open-answer-image-mode" if question.show_images?

    classes.join(" ")
  end

  private

    def user_answers
      @user_answers ||= question.answers.by_author(current_user)
    end

    def any_remaining_votes?
      if question.votation_type&.multiple?
        user_answers.count < question.max_votes
      else
        user_answers.empty?
      end
    end
end
