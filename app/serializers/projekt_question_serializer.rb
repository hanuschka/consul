class ProjektQuestionSerializer < BaseSerializer
  attr_reader :projekt_question

  def initialize(projekt_question)
    @projekt_question = projekt_question
  end

  def serialize
    question_data = projekt_question.as_json(
      only: [
        :id,
        :author_id,
        :projekt_phase_id,
        :projekt_livestream_id,
        :created_at,
        :updated_at
      ]
    )

    question_data.merge!(
      title: projekt_question.title
    )

    if projekt_question.author.present?
      question_data[:author] = {
        id: projekt_question.author.id,
        username: projekt_question.author.username,
        public_name: projekt_question.author.public_name
      }
    end

    if projekt_question.projekt_phase.present?
      question_data[:projekt_phase] = {
        id: projekt_question.projekt_phase.id,
        title: projekt_question.projekt_phase.phase_tab_name,
        type: projekt_question.projekt_phase.type,
        projekt_id: projekt_question.projekt_phase.projekt_id
      }

      if projekt_question.projekt_phase.projekt.present?
        projekt = projekt_question.projekt_phase.projekt
        question_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    if projekt_question.projekt_livestream.present?
      question_data[:projekt_livestream] = {
        id: projekt_question.projekt_livestream.id,
        title: projekt_question.projekt_livestream.title,
        url: projekt_question.projekt_livestream.url
      }
    end

    if projekt_question.question_options.any?
      question_data[:question_options] = projekt_question.question_options.map do |option|
        {
          id: option.id,
          title: option.title,
          description: option.description
        }
      end
    end

    question_data[:answers_count] = projekt_question.answers.count if projekt_question.respond_to?(:answers)

    question_data
  end

  def self.serialize_collection(questions)
    questions.map { |question| new(question).serialize }
  end
end

