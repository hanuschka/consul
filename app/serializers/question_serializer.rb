class QuestionSerializer < BaseSerializer
  PRELOADS = [
    :translations,
    :projekt_livestream,
    { question_options: :translations },
    { author: :organization },
    { projekt_phase: { projekt: :page } }
  ].freeze

  attr_reader :projekt_question

  def initialize(projekt_question, client: nil)
    @projekt_question = projekt_question
    @client = client
  end

  def serialize
    question_data = projekt_question.as_json(
      only: [
        :id,
        :projekt_phase_id,
        :projekt_livestream_id,
        :comments_enabled,
        :show_answers_count,
        :created_at,
        :updated_at
      ]
    )

    question_data.merge!(
      title: projekt_question.title,
      translations: serialize_translations(projekt_question)
    )

    if admin_client?
      question_data[:author_id] = projekt_question.author_id
    end

    if projekt_question.author.present?
      question_data[:author] = serialize_author(projekt_question.author)
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
        serialize_option(option)
      end
    end

    if answer_counts_visible?
      question_data[:answers_count] = projekt_question.answers_count
    end

    question_data
  end

  def self.serialize_collection(questions, client: nil)
    questions.map { |question| new(question, client: client).serialize }
  end

  private

    def answer_counts_visible?
      admin_client? || projekt_question.show_answers_count
    end

    def serialize_option(option)
      option_data = { id: option.id, value: option.value }

      if answer_counts_visible?
        option_data[:answers_count] = option.answers_count
      end

      option_data
    end
end

