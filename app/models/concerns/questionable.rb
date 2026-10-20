module Questionable
  extend ActiveSupport::Concern

  included do
    has_one :votation_type, as: :questionable, dependent: :destroy
    accepts_nested_attributes_for :votation_type
    # delegate :max_votes, :multiple?, :vote_type, to: :votation_type, allow_nil: true
    delegate :multiple?, :map_points?, :rating_scale?, :vote_type, to: :votation_type, allow_nil: true # custom
  end

  def unique?
    votation_type.nil? || votation_type.unique?
  end

  def find_or_initialize_user_answer(user, question_answer)
    answer = answers.find_or_initialize_by(find_by_attributes(user, question_answer))

    if answer.question_answer_id != question_answer&.id
      answer.question_answer = question_answer
      answer.answer = question_answer&.title
    end

    answer
  end

  private

    def find_by_attributes(user, question_answer)
      case vote_type
      when "unique", nil
        { author: user }
      when "multiple"
        { author: user, question_answer_id: question_answer&.id }
      end
    end
end
