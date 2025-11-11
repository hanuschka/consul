class Poll::Question::AnswerSerializer < BaseSerializer
  attr_reader :answer

  def initialize(answer)
    @answer = answer
  end

  def serialize
    answer_data = answer.as_json(
      only: [
        :id,
        :given_order,
        :created_at,
        :updated_at
      ]
    )

    answer_data.merge!(
      title: answer.title,
      description: answer.description
    )

    answer_data[:total_votes] = answer.total_votes
    answer_data[:total_votes_percentage] = answer.total_votes_percentage

    answer_data
  end

  def self.serialize_collection(answers)
    answers.map { |answer| new(answer).serialize }
  end
end
