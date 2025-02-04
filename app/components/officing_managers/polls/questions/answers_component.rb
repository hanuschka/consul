class OfficingManagers::Polls::Questions::AnswersComponent < ApplicationComponent
  attr_reader :question, :responding_user
  delegate :answer_with_description?, to: :helpers

  def initialize(question, user, answer_updated: nil, open_answer_updated: nil)
    @question = question
    @responding_user = user
    @answer_updated = answer_updated
    @open_answer_updated = open_answer_updated
  end

  def already_answered?(question_answer)
    user_answer(question_answer).present?
  end

  def question_answers
    question.question_answers
  end

  def user_answer(question_answer)
    user_answers.find_by(answer: question_answer.title)
  end

  def should_show_answer_weight?
    question&.votation_type&.multiple_with_weight? &&
      question.max_votes.present?
  end

  def available_vote_weight(question_answer)
    return 0 unless responding_user.present?

    if user_answer(question_answer).present?
      question.max_votes -
        question.answers.where(author_id: responding_user.id).sum(:answer_weight) +
        user_answer(question_answer).answer_weight
    else
      question.max_votes -
        question.answers.where(author_id: responding_user.id).sum(:answer_weight)
    end
  end

  def disable_answer?(question_answer)
    return false unless responding_user.present?

    (question.votation_type&.multiple? && user_answers.count == question.max_votes) ||
      (question.votation_type&.multiple_with_weight? && available_vote_weight(question_answer) == 0)
  end

  private

    def user_answers
      @user_answers ||= question.answers.by_author(responding_user)
    end
end
