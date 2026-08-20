# frozen_string_literal: true

class Polls::Questions::RegularAnswersComponent < Polls::Questions::AnswersComponent
  def displayed_answers
    answers = answer_scope.to_a
    open_answer = answers.select(&:open_answer).last

    ordered = answers.reject(&:open_answer)
    ordered += [open_answer] if open_answer

    question.answers_in_participant_order(ordered, helpers.poll_participant_order_seed)
  end

  def answer_scope
    answers = question.question_answers
    return answers if answers.loaded?

    answers.includes(:translations, :images, :documents, :videos)
  end

  def answer_form_class(question_answer)
    if question_answer.more_info_link.present? || show_additional_info_description?(question_answer)
      "poll-answer-form--wide"
    else
      "poll-answer-form"
    end
  end
end
