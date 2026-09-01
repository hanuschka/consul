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
        :show_images,
        :answer_mandatory,
        :bundle_question,
        :randomize_answers,
        :randomize_position,
        :created_at,
        :updated_at
      ]
    )

    question_data.merge!(
      title: question.title,
      description: question.description,
      intro: question.intro,
      vote_type: question.votation_type&.vote_type,
      show_hint_callout: question.votation_type&.show_hint_callout
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
