require_dependency Rails.root.join("app", "models", "poll", "question").to_s

class Poll::Question < ApplicationRecord
  include Mappable

  accepts_nested_attributes_for :map_location, allow_destroy: true, update_only: true

  translates :description, :min_rating_scale_label, :max_rating_scale_label, :intro, touch: true
  has_many :nested_questions, -> { order "given_order asc" },
    class_name: "Poll::Question", dependent: :destroy, foreign_key: :parent_question_id

  belongs_to :parent_question, class_name: "Poll::Question", optional: true
  belongs_to :contextualize_by_question, class_name: "Poll::Question",
                                         foreign_key: :contextualize_by_poll_question_id,
                                         optional: true
  belongs_to :contexted_clone_of, class_name: "Poll::Question",
                                  foreign_key: :contexted_clone_of_poll_question_id,
                                  optional: true,
                                  inverse_of: :contexted_clones
  has_many :contexted_clones, class_name: "Poll::Question",
                              foreign_key: :contexted_clone_of_poll_question_id,
                              inverse_of: :contexted_clone_of,
                              dependent: :destroy
  belongs_to :context, class_name: "Poll::Question::Answer",
                       foreign_key: :context_id,
                       optional: true

  scope :with_wizard_associations, -> {
    answer_includes = [:translations, :images, :documents, :videos]

    includes(:context, :poll, :translations, :votation_type,
             question_answers: answer_includes,
             nested_questions: [:poll, :votation_type, :translations, { question_answers: answer_includes }])
  }

  validates :votation_type, presence: true
  validate :validate_parent_question_id
  before_validation :clear_randomize_position_if_impossible

  scope :root_questions, -> {
    where(parent_question_id: nil)
  }

  scope :in_configured_order, -> {
    joins(
      "LEFT JOIN poll_questions contexted_templates " \
      "ON contexted_templates.id = poll_questions.contexted_clone_of_poll_question_id"
    ).reorder(
      Arel.sql(
        "COALESCE(contexted_templates.given_order, poll_questions.given_order) ASC, poll_questions.id ASC"
      )
    )
  }

  def self.order_questions(ordered_array)
    ordered_array.reject(&:blank?).each_with_index do |question_id, order|
      find(question_id).update_column(:given_order, (order + 1))
    end
  end

  def self.model_name
    mname = super
    mname.instance_variable_set(:@route_key, "questions")
    mname.instance_variable_set(:@singular_route_key, "question")
    mname
  end

  def open_question_answer
    return @open_question_answer if defined?(@open_question_answer)

    @open_question_answer = question_answers.select(&:open_answer).last
  end

  def max_map_points
    votation_type&.max_votes.presence || 1
  end

  def randomize_answers_possible?
    !rating_scale? && !map_points?
  end

  def answers_in_participant_order(answers, seed)
    return answers.to_a unless randomize_answers? && randomize_answers_possible?

    open_answers, regular_answers = answers.partition(&:open_answer)

    regular_answers.sort_by { |answer| Digest::SHA256.hexdigest("#{seed}:#{id}:#{answer.id}") } + open_answers
  end

  def randomize_position_possible?
    randomize_position_block_reason.nil?
  end

  def randomize_position_block_reason
    return :bundle if bundle_question? || parent_question_id.present?

    if contextualize_by_poll_question_id.present? || context_id.present? ||
        contexted_clone_of_poll_question_id.present?
      return :contextualization
    end

    return nil unless persisted?
    return :contextualization if contextualized_dependents.exists?
    return :branching if question_answers.where.not(next_question_id: nil).exists?
    return :branching if Poll::Question::Answer.where(next_question_id: id).exists?

    nil
  end

  def clear_randomize_position_if_impossible
    return unless randomize_position?

    self.randomize_position = false unless randomize_position_possible?
  end

  def allows_multiple_answers?
    VotationType.allowing_multiple_answers.include?(votation_type.vote_type)
  end

  def validate_parent_question_id
    if parent_question_id.present?
      question_ids = poll.questions.ids

      if question_ids.exclude?(parent_question_id)
        errors.add(:base, "Parent question doesn't belong to the same poll")
      end
    end
  end

  def sibling_questions
    (poll.questions.where(parent_question_id: nil).to_a - [self]).map do |question|
 [question.title, question.id] end
  end

  def allows_additional_info?
    votation_type.unique? || votation_type.multiple? || votation_type.multiple_with_weight?
  end

  def can_accept_open_answer?
    votation_type.unique? || votation_type.multiple?
  end

  def find_or_clone_for_context(ctx)
    return unless template_for_context?
    return if context.present?

    poll.questions.with_context(ctx).find_by(title:) || clone_for_context(ctx)
  end

  def regenerate_contexted_clones
    # Clones are disposable, regenerated artifacts. Hard-delete them (Poll::Question
    # is acts_as_paranoid) so their rows — and the context_id FK they hold to the
    # source answers — are actually removed, otherwise soft-deleted clones would
    # block those answers from ever being deleted.
    contexted_clones.each(&:really_destroy!)

    contextualize_by_question.question_answers.each do |qa|
      clone_for_context(qa)
    end
  end

  # Questions in the same poll that use this question as their contextualisation
  # source. Their contexted clones depend on this question's answer set, so they
  # must be regenerated whenever this question's answers change.
  def contextualized_dependents
    poll.questions.where(contextualize_by_poll_question_id: id)
  end

  # Auto-regeneration entry point for the /adm edit flow. Rebuilds the contexted
  # clones unless the poll already has voters — regeneration destroys and recreates
  # the clone questions, which would discard any votes already cast on them. The
  # manual admin action (#regenerate_contexted_clones) stays available to force a
  # rebuild deliberately. Returns true when it regenerated, false when it skipped.
  def regenerate_contexted_clones_if_safe
    return false unless contextualize_by_question
    return false unless poll.safe_to_delete_answer?

    regenerate_contexted_clones
    true
  end

  protected

    def clone_for_context(context, nested: false)
      new_question = dup
      new_question.contextualize_by_poll_question_id = nil
      new_question.contexted_clone_of = self unless nested
      new_question.context = context unless nested

      new_question.comments_count = 0

      new_question.title = title
      new_question.description = description
      new_question.min_rating_scale_label = min_rating_scale_label
      new_question.max_rating_scale_label = max_rating_scale_label
      new_question.intro = intro

      question_answers.each do |question_answer|
        new_question_answer = question_answer.dup
        new_question_answer.title = question_answer.title
        new_question_answer.description = question_answer.description
        new_question.question_answers << new_question_answer
      end

      new_votation_type = votation_type.dup
      new_votation_type.save!
      new_question.votation_type = new_votation_type

      new_question.save!

      if bundle_question?
        nested_questions.each do |nested_question|
          nested_question_clone = nested_question.clone_for_context(context, nested: true)
          new_question.nested_questions << nested_question_clone
        end
      end

      new_question
    end
end
# Also clone videos, documents and images for answers
