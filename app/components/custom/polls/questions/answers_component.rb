require_dependency Rails.root.join("app", "components", "polls", "questions", "answers_component").to_s

class Polls::Questions::AnswersComponent < ApplicationComponent
  delegate :projekt_feature?, :projekt_phase_feature?, :answer_with_description?, to: :helpers

  def initialize(question, answer_updated: nil, open_answer_updated: nil)
    @question = question
    @answer_updated = answer_updated
    @open_answer_updated = open_answer_updated
  end

  def question_answers
    question.answers_in_participant_order(question.question_answers, helpers.poll_participant_order_seed)
  end

  def poll_question_answers_class
    classes = ["poll-question-answers"]

    if question&.votation_type&.rating_scale?
      classes.push("rating-scale js-rating-scale")
    elsif show_additional_info_images?
      classes.push("regular")
      classes.push("regular-with-images")

    else
      classes.push("regular")
    end

    classes.join(" ")
  end

  def poll_answer_group_class
    classes = ["poll-answer-group"]

    if show_additional_info_images?
      classes.push("align-answers-top image-answers")
    end

    classes.join(" ")
  end

  def button_not_answered_class
    if question.votation_type&.rating_scale?
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

  def show_additional_info_images?
    return if question&.votation_type&.rating_scale?

    question.show_images?
  end

  def show_additional_info_description?(question_answer)
    return if question&.votation_type&.rating_scale?

    answer_with_description?(question_answer)
  end

  def should_show_answer_weight?
    question&.votation_type&.multiple_with_weight? &&
      question.max_votes.present?
  end

  # Both read from Polls::AnswerAllowanceQuery, which is what the controller refuses
  # a write against: a button the page leaves enabled past the maximum is a tap that
  # is now rejected on arrival, and a selector offering more weight than is free is
  # a number the write would reduce anyway.
  #
  # This one also gained the per-answer cap the form component always applied and
  # this one never did — the two disagreed about max_votes_per_answer, and the
  # stricter of them is the one the write honours.
  def available_vote_weight(question_answer)
    return 0 if current_user.blank?

    ::Polls::AnswerAllowanceQuery.remaining_weight(
      question: question, user: current_user, title: question_answer.title,
      recorded_answers: user_answers
    )
  end

  def disable_answer?(question_answer)
    return false if current_user.blank?

    !::Polls::AnswerAllowanceQuery.call(
      question: question, user: current_user, title: question_answer.title,
      recorded_answers: user_answers
    )
  end

  def has_additional_info?(question_answer)
    question_answer.more_info_link.present? ||
      question_answer.more_info_iframe.present? ||
      show_additional_info_images? ||
      show_additional_info_description?(question_answer)
  end

  def new_design?
    Setting.new_design_enabled?
  end
end
