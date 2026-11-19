# Votes per answer option for a set of questions, from four grouped queries
# instead of one query per answer. Online answers count with their weight,
# booth results with their amount; open answers count each non-empty text.
class Polls::AnswerVoteTotals < ApplicationService
  Totals = Struct.new(
    :weighted, :open_counts, :partial_amounts, :partial_counts,
    keyword_init: true
  ) do
    def votes_for(answer)
      key = [answer.question_id, answer.id]

      if answer.open_answer?
        open_counts.fetch(key, 0) + partial_counts.fetch(key, 0)
      else
        weighted.fetch(key, 0) + partial_amounts.fetch(key, 0)
      end
    end

    def question_total(question)
      question.question_answers.sum { |answer| votes_for(answer) }
    end

    def percentage_for(answer, question)
      total = question_total(question)
      return 0 if total.zero?

      (votes_for(answer) * 100.0) / total
    end
  end

  def initialize(question_ids)
    @question_ids = question_ids
  end

  def call
    if question_ids.empty?
      return Totals.new(weighted: {}, open_counts: {}, partial_amounts: {}, partial_counts: {})
    end

    Totals.new(
      weighted:
        answers
          .where.not(question_answer_id: nil)
          .group(:question_id, :question_answer_id)
          .sum(:answer_weight),
      open_counts:
        answers
          .where.not(open_answer_text: [nil, ""])
          .group(:question_id, :question_answer_id)
          .count,
      partial_amounts: partial_results.group(:question_id, :question_answer_id).sum(:amount),
      partial_counts: partial_results.group(:question_id, :question_answer_id).count
    )
  end

  private

    attr_reader :question_ids

    def answers
      Poll::Answer.where(question_id: question_ids)
    end

    def partial_results
      ::Poll::PartialResult.where(question_id: question_ids)
    end
end
