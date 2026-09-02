require_dependency Rails.root.join("app", "models", "poll", "question", "answer").to_s

class Poll::Question::Answer < ApplicationRecord
  belongs_to :next_question, class_name: "Poll::Question", optional: true,
    foreign_key: "next_question_id", inverse_of: "previous_question"

  delegate :author_id, to: :question

  after_save :clear_randomize_position_on_branching

  default_scope { includes(:translations, :images, :documents, :videos) }

  def self.model_name
    mname = super
    mname.instance_variable_set(:@route_key, "answers")
    mname.instance_variable_set(:@singular_route_key, "answer")
    mname
  end

  def all_open_answers
    return [] unless open_answer?

    Poll::Answer.where(question_id: question, answer: title).where.not(open_answer_text: [nil, ""])
  end

  def all_open_answers_connected_to(base_question_answer)
    answered_base_question_answer_user_ids = Poll::Answer
      .where(question_id: base_question_answer.question, answer: base_question_answer.title)
      .pluck(:author_id)
    all_open_answers.where(author_id: answered_base_question_answer_user_ids)
  end

  def total_votes
    if open_answer?
      all_open_answers.count +
        ::Poll::PartialResult.where(question: question).where(answer: title).count
    else
      Poll::Answer.where(question_id: question, answer: title).sum(:answer_weight) +
        ::Poll::PartialResult.where(question: question).where(answer: title).sum(:amount)
    end
  end

  def total_votes_percentage
    question.answers_total_votes.zero? ? 0 : (total_votes * 100.0) / question.answers_total_votes
  end

  def total_voters
    Poll::Answer.where(question_id: question, answer: title).distinct.count(:author_id)
  end

  def weight_distribution
    Poll::Answer.where(question_id: question, answer: title).group(:answer_weight).count
  end

  def total_connected_votes_to(base_question_answer)
    answered_base_question_answer_user_ids = Poll::Answer
      .where(question_id: base_question_answer.question, answer: base_question_answer.title)
      .pluck(:author_id)
    Poll::Answer
      .where(question_id: question, answer: title, author_id: answered_base_question_answer_user_ids)
      .sum(:answer_weight)
  end

  def total_connected_votes_inner_share(base_question_answer)
    answered_base_question_answer_user_ids = Poll::Answer
      .where(question_id: base_question_answer.question, answer: base_question_answer.title)
      .pluck(:author_id)

    all_connected_answers_count = Poll::Answer
      .where(question_id: question, author_id: answered_base_question_answer_user_ids)
      .sum(:answer_weight)

    return 0 if all_connected_answers_count.zero?

    total_connected_votes_to(base_question_answer) * 100.0 / all_connected_answers_count
  end

  private

    def clear_randomize_position_on_branching
      return if next_question_id.blank?

      Poll::Question.where(id: [question_id, next_question_id], randomize_position: true)
                    .update_all(randomize_position: false)
    end
end
