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
    # question.open_question_answer.present? && already_answered?(question.open_question_answer)
    can?(:answer, question) &&
      question.open_question_answer.present?
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
end
