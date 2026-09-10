class Poll::Answer < ApplicationRecord
  include VotesAQuestionAnswer

  audited if: :audit_changes?

  belongs_to :question, -> { with_hidden }, inverse_of: :answers
  belongs_to :author, ->   { with_hidden }, class_name: "User", inverse_of: :poll_answers

  has_many :map_points, class_name: "Poll::Answer::MapPoint", foreign_key: :poll_answer_id,
                        inverse_of: :answer, dependent: :destroy

  delegate :poll, :poll_id, to: :question
  delegate :map_points?, to: :question, allow_nil: true

  validates :question, presence: true
  validates :author, presence: true
  validates :answer, presence: true, unless: :map_points?
  validates :question_answer, presence: true, unless: :map_points?
  validate :max_votes

  scope :by_author, ->(author_id) { where(author_id: author_id) }
  scope :by_question, ->(question_id) { where(question_id: question_id) }

  def save_and_record_voter_participation
    transaction do
      touch if persisted?
      save!
      Poll::Voter.find_or_create_by!(user: author, poll: poll, origin: "web")
    end
  end

  def destroy_and_remove_voter_participation
    transaction do
      destroy!

      if author.poll_answers.where(question_id: poll.question_ids).none?
        Poll::Voter.find_by(user: author, poll: poll, origin: "web").destroy!
      end
    end
  end

  private

    def max_votes
      return if !question || question&.unique? || question.votation_type&.rating_scale?
      return if map_points?

      author.save! if author.guest? && author.changed == ["locale"]
      author.lock!

      used_weight = question.answers.by_author(author)
        .where.not(question_answer_id: question_answer_id)
        .sum(:answer_weight)

      available_weight = [question.max_votes - used_weight,
                          question.votation_type.max_votes_per_answer].compact.min

      if answer_weight > available_weight
        raise "Maximum number of votes per user exceeded"
      end
    end

    def audit_changes?
      officing_manager_id.present?
    end
end
