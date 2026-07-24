# frozen_string_literal: true

class Polls::Questions::RegularAnswersComponent < Polls::Questions::AnswersComponent
  def question_answers
    question.question_answers.reject(&:open_answer)
  end

  def answer_form_class(question_answer)
    if question_answer.more_info_link.present? || show_additional_info_description?(question_answer)
      "poll-answer-form--wide"
    else
      "poll-answer-form"
    end
  end
end
