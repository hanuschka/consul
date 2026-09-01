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
        :open_answer,
        :more_info_link,
        :more_info_iframe,
        :next_question_id,
        :terminates_poll
      ]
    )

    answer_data.merge!(
      title: answer.title,
      description: answer.description
    )

    answer_data[:total_votes] = answer.total_votes
    answer_data[:total_votes_percentage] = answer.total_votes_percentage

    if answer.videos.any?
      answer_data[:videos] = answer.videos.map do |video|
        { id: video.id, title: video.title, url: video.url }
      end
    end

    answer_data
  end

  def self.serialize_collection(answers)
    answers.map { |answer| new(answer).serialize }
  end
end
