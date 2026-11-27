class Poll::QuestionSerializer < BaseSerializer
  TRANSLATED_ATTRIBUTES = %w[title description intro].freeze
  RATING_LABEL_ATTRIBUTES = %w[min_rating_scale_label max_rating_scale_label].freeze

  ANSWER_PRELOADS = [:translations, :videos, :documents, { images: { attachment_attachment: :blob } }].freeze

  PRELOADS = [
    :translations,
    :map_location,
    { votation_type: :translations },
    { question_answers: ANSWER_PRELOADS },
    :nested_questions
  ].freeze

  attr_reader :question

  def initialize(question, vote_totals: nil)
    @question = question
    @vote_totals = vote_totals
  end

  def serialize
    question_data = question.as_json(
      only: [
        :id,
        :poll_id,
        :multiple,
        :given_order,
        :show_images,
        :answer_mandatory,
        :bundle_question,
        :randomize_answers,
        :randomize_position,
        :parent_question_id,
        :contextualize_by_poll_question_id,
        :context_id,
        :contexted_clone_of_poll_question_id,
        :created_at,
        :updated_at
      ]
    )

    question_data.merge!(
      title: question.title,
      description: question.description,
      intro: question.intro,
      translations: serialize_translations(question, TRANSLATED_ATTRIBUTES),
      vote_type: question.votation_type&.vote_type,
      show_hint_callout: question.votation_type&.show_hint_callout,
      votation_type: serialize_votation_type,
      map_location: serialize_map_location(question.map_location),
      nested_question_ids: question.nested_questions.map(&:id)
    )

    if question.question_answers.any?
      question_data[:answers] = Poll::Question::AnswerSerializer.serialize_collection(
        question.question_answers,
        vote_totals: @vote_totals
      )
    end

    question_data
  end

  def self.serialize_collection(questions, vote_totals: nil)
    questions.map { |question| new(question, vote_totals: vote_totals).serialize }
  end

  private

    def serialize_votation_type
      votation_type = question.votation_type
      return nil if votation_type.blank?

      {
        vote_type: votation_type.vote_type,
        max_votes: votation_type.max_votes,
        max_votes_per_answer: votation_type.max_votes_per_answer,
        show_hint_callout: votation_type.show_hint_callout,
        min_rating_scale_label: votation_type.min_rating_scale_label,
        max_rating_scale_label: votation_type.max_rating_scale_label,
        translations: serialize_translations(votation_type, RATING_LABEL_ATTRIBUTES)
      }
    end
end
