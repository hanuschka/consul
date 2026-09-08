module VotesAQuestionAnswer
  extend ActiveSupport::Concern

  included do
    belongs_to :question_answer, class_name: "Poll::Question::Answer", optional: true

    before_validation :resolve_question_answer, on: :create
    before_validation :snapshot_answer_text, on: :create
    validate :question_answer_belongs_to_question
  end

  private

    def resolve_question_answer
      return if question_answer_id.present?
      return if question_id.blank? || answer.blank?

      candidates = Poll::Question::Answer.unscoped
        .joins(:translations)
        .where(question_id: question_id, poll_question_answer_translations: { title: answer })
        .distinct
        .limit(2)
        .ids

      self.question_answer_id = candidates.first if candidates.one?
    end

    def snapshot_answer_text
      return if answer.present? || question_answer.blank?

      self.answer = question_answer.title
    end

    def question_answer_belongs_to_question
      return if question_answer.blank? || question_id.blank?
      return if question_answer.question_id == question_id

      errors.add(:question_answer, :invalid)
    end
end
