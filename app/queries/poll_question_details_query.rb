class PollQuestionDetailsQuery < ApplicationQuery
  def initialize(question)
    @question = question
  end

  def participation
    ProjektPhaseStats::UserSegmentsQuery.call(Poll::Question::Stats.new(question))
  end

  def crossectional
    answers.map { |answer| crossectional_for_answer(answer) }
  end

  def crossectional_for_answer(answer)
    { answer: answer.title, groups: crossectional_groups(voter_ids_by_answer[answer.title] || []) }
  end

  private

    attr_reader :question

    def answers
      @answers ||= question.question_answers.sort_by(&:given_order)
    end

    def other_questions
      @other_questions ||= question.poll.questions
        .root_questions
        .where.not(id: question.id)
        .includes(:question_answers)
        .to_a
    end

    def voter_ids_by_answer
      @voter_ids_by_answer ||= question.answers
        .pluck(:author_id, :answer)
        .group_by { |(_author_id, answer)| answer }
        .transform_values { |pairs| pairs.map(&:first).uniq }
    end

    def crossectional_groups(voter_ids)
      counts = counts_by_question(voter_ids)

      other_questions.map do |other_question|
        question_counts = counts[other_question.id] || {}
        total = question_counts.values.sum

        rows = other_question.question_answers.sort_by(&:given_order).map do |answer|
          count = question_counts[answer.title].to_i

          {
            title: answer.title,
            count: count,
            share: total.zero? ? 0 : (count * 100.0 / total).round(1)
          }
        end

        { question: other_question.title, answers: rows }
      end
    end

    def counts_by_question(voter_ids)
      return {} if voter_ids.empty?

      Poll::Answer
        .where(question_id: other_questions.map(&:id), author_id: voter_ids)
        .where.not(answer: nil)
        .group(:question_id, :answer)
        .count
        .each_with_object({}) do |((question_id, answer), count), acc|
          (acc[question_id] ||= {})[answer] = count
        end
    end
end
