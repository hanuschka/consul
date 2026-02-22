class Poll::QuestionSerializer < BaseSerializer
  attr_reader :question

  def initialize(question)
    @question = question
  end

  def serialize
    question_data = question.as_json(
      only: [
        :id,
        :multiple,
        :given_order,
        :created_at,
        :updated_at
      ]
    )

    question_data.merge!(
      title: question.title
    )

    if question.question_answers.any?
      question_data[:answers] = question.question_answers.map do |answer|
        Poll::Question::AnswerSerializer.new(answer).serialize
      end
    end

    question_data
  end

  def self.serialize_collection(questions)
    questions.map { |question| new(question).serialize }
  end
end
