class Poll::Question::AnswerSerializer < BaseSerializer
  TRANSLATED_ATTRIBUTES = %w[title description].freeze

  attr_reader :answer

  # Vote counts are only included when the caller passes the poll's totals,
  # which it does where the client may see the results.
  def initialize(answer, vote_totals: nil)
    @answer = answer
    @vote_totals = vote_totals
  end

  def serialize
    answer_data = answer.as_json(
      only: [
        :id,
        :question_id,
        :given_order,
        :open_answer,
        :more_info_link,
        :more_info_iframe,
        :next_question_id,
        :terminates_poll
      ]
    )

    answer_data.merge!(
      title: answer.title,
      description: answer.description,
      translations: serialize_translations(answer, TRANSLATED_ATTRIBUTES),
      images: answer.images.filter_map { |image| ImageSerializer.new(image, include_variants: false).serialize },
      documents: DocumentSerializer.serialize_collection(answer.documents)
    )

    if @vote_totals.present?
      answer_data[:total_votes] = @vote_totals.votes_for(answer)
      answer_data[:total_votes_percentage] = @vote_totals.percentage_for(answer, answer.question)
    end

    if answer.videos.any?
      answer_data[:videos] = answer.videos.map do |video|
        { id: video.id, title: video.title, url: video.url }
      end
    end

    answer_data
  end

  def self.serialize_collection(answers, vote_totals: nil)
    answers.map { |answer| new(answer, vote_totals: vote_totals).serialize }
  end
end
