class QuestionOptionSerializer < BaseSerializer
  attr_reader :question_option

  def initialize(question_option)
    @question_option = question_option
  end

  def serialize
    option_data = question_option.as_json(
      only: [
        :id,
        :projekt_question_id,
        :created_at,
        :updated_at
      ]
    )

    option_data.merge!(
      value: question_option.value
    )

    if question_option.question.present?
      option_data[:question] = {
        id: question_option.question.id,
        title: question_option.question.title
      }
    end

    option_data[:answers_count] = question_option.answers.count if question_option.respond_to?(:answers)

    option_data
  end

  def self.serialize_collection(options)
    options.map { |option| new(option).serialize }
  end
end
