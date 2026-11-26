# Aggregated results of a poll for the API: voters, votes and voters per
# answer option, the weight distribution of weighted and rating questions,
# and the anonymous points of map questions. Never single votes, open answer
# texts or who answered.
class Polls::ResultsSummary < ApplicationService
  WEIGHTED_VOTE_TYPES = %w[multiple_with_weight rating_scale].freeze

  def initialize(poll)
    @poll = poll
  end

  def call
    {
      poll_id: poll.id,
      live: poll.live?,
      voters_count: poll.voters.count,
      questions: root_questions.map { |question| serialize_question(question) }
    }
  end

  private

    attr_reader :poll

    def root_questions
      @root_questions ||=
        poll.questions
          .root_questions
          .includes(
            :translations, :votation_type, :question_answers,
            nested_questions: [:translations, :votation_type, :question_answers]
          )
          .order(:given_order, :id)
          .to_a
    end

    def question_ids
      @question_ids ||=
        root_questions.flat_map do |question|
          [question.id, *question.nested_questions.map(&:id)]
        end
    end

    def vote_totals
      @vote_totals ||= Polls::AnswerVoteTotals.call(question_ids)
    end

    def voters_by_answer
      @voters_by_answer ||=
        Poll::Answer
          .where(question_id: question_ids)
          .where.not(question_answer_id: nil)
          .group(:question_answer_id)
          .distinct
          .count(:author_id)
    end

    def weights_by_answer
      @weights_by_answer ||=
        Poll::Answer
          .where(question_id: question_ids)
          .where.not(question_answer_id: nil)
          .group(:question_answer_id, :answer_weight)
          .count
          .group_by { |(answer_id, _weight), _count| answer_id }
          .transform_values do |weight_counts|
            weight_counts
              .map { |(_answer_id, weight), count| { weight: weight, count: count } }
              .sort_by { |weight_count| weight_count[:weight].to_i }
          end
    end

    def serialize_question(question)
      vote_type = question.votation_type&.vote_type

      question_data = {
        id: question.id,
        title: question.title,
        vote_type: vote_type,
        max_votes: question.votation_type&.max_votes,
        total_votes: vote_totals.question_total(question),
        answers: question.question_answers.map { |answer| serialize_answer(answer, question, vote_type) },
        nested_questions: question.nested_questions.map { |nested_question| serialize_question(nested_question) }
      }

      if vote_type == "map_points"
        question_data[:map_points] = Polls::MapPointsFeatureCollection.call(question)
      end

      question_data
    end

    def serialize_answer(answer, question, vote_type)
      answer_data = {
        id: answer.id,
        title: answer.title,
        open_answer: answer.open_answer,
        total_votes: vote_totals.votes_for(answer),
        percentage: vote_totals.percentage_for(answer, question).round(2),
        voters_count: voters_by_answer.fetch(answer.id, 0)
      }

      if WEIGHTED_VOTE_TYPES.include?(vote_type)
        answer_data[:weights] = weights_by_answer.fetch(answer.id, [])
      end

      answer_data
    end
end
