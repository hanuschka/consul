class QuestionOptionSerializer < BaseSerializer
  attr_reader :question_option

  def initialize(question_option, client: nil)
    @question_option = question_option
    @client = client
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
      value: question_option.value,
      translations: serialize_translations(question_option)
    )

    if question_option.question.present?
      option_data[:question] = {
        id: question_option.question.id,
        title: question_option.question.title
      }
    end

    if admin_client? || question_option.question&.show_answers_count
      option_data[:answers_count] = question_option.answers_count
    end

    option_data
  end

  def self.serialize_collection(options, client: nil)
    options.map { |option| new(option, client: client).serialize }
  end
end
