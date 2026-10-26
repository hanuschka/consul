require_dependency Rails.root.join("app", "models", "concerns", "questionable").to_s

module Questionable
  def max_votes
    votation_type.max_votes || question_answers.count
  end

  private

    def find_by_attributes(user, question_answer)
      case vote_type
      when "unique", nil, "rating_scale"
        { author: user }
      when "multiple", "multiple_with_weight"
        { author: user, question_answer_id: question_answer&.id }
      end
    end
end
