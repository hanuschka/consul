require_dependency Rails.root.join("app", "models", "poll").to_s

class Poll < ApplicationRecord
  include Taggable
  include ResourceBelongsToProjekt

  belongs_to :old_projekt, class_name: "Projekt", foreign_key: "projekt_id" # TODO: remove column after data migration con1538

  delegate :projekt, to: :projekt_phase, allow_nil: true

  has_many :geozone_restrictions, through: :projekt_phase
  has_many :geozone_affiliations, through: :projekt
  has_many :registered_address_district_affiliations, through: :projekt

  belongs_to :projekt_phase
  validates :projekt_phase, presence: true

  enum ai_stats_refresh_status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, _prefix: :ai_stats_refresh

  scope :last_week, -> { where("polls.created_at >= ?", 7.days.ago) }

  scope :for_public_render, -> {
    created_by_admin
      .not_budget
      .includes(:geozones)
  }

  def not_allow_user_geozone?(user)
    geozone_restricted? && geozone_ids.any? && !geozone_ids.include?(user.geozone_id)
  end

  def citizen_not_alloed?(user)
    geozone_restricted? && geozone_ids.empty? && user.not_current_city_citizen?
  end

  def geozone_restrictions_formatted
    geozones.map(&:name).flatten.join(", ")
  end

  def self.base_selection
    created_by_admin.not_budget
  end

  def answerable_by?(user)
    projekt_phase.permission_problem(user).blank?
  end

  def reason_for_not_being_answerable_by(user)
    projekt_phase.permission_problem(user)
  end

  def comments_allowed?(user)
    answerable_by?(user)
  end

  def find_or_create_stats_version
    ends_at = projekt_phase&.end_date

    if ends_at.present? &&
        ((Time.zone.today - ends_at.to_date).to_i <= 3) &&
        stats_version.present? &&
        stats_version.created_at.to_date != Time.zone.today.to_date
      stats_version.destroy
    end

    super
  end

  def safe_to_delete_answer?
    voters.count == 0 || !live?
  end

  # Transition a poll out of test mode. Everything accumulated while the poll was
  # not live is test data (admins/officers test via the officing booth; the public
  # is blocked by the :poll_not_live phase restriction), so it is purged before the
  # poll goes live to guarantee real results start from a clean slate.
  def go_live!
    transaction do
      question_ids = questions.with_deleted.ids
      Poll::Answer.where(question_id: question_ids).delete_all
      Poll::PartialResult.where(question_id: question_ids).delete_all
      Poll::Voter.where(poll_id: id).delete_all
      update!(live: true)
    end
  end

  def stats_age_groups
    return [] if projekt_phase.blank?

    projekt_phase.age_ranges_for_stats.map { |ar| [ar.effective_min_age, ar.effective_max_age] }
  end

  def in_wizard_mode?
    projekt_phase.feature?("resource.wizard_mode")
  end

  def questions_in_participant_order(questions, seed)
    ordered = questions.to_a.dup
    slots = ordered.each_index.select { |index| ordered[index].randomize_position? }
    return ordered if slots.size < 2

    shuffled = slots.map { |index| ordered[index] }
                    .sort_by { |question| Digest::SHA256.hexdigest("#{seed}:#{id}:#{question.id}") }

    slots.each_with_index { |slot, index| ordered[slot] = shuffled[index] }

    ordered
  end

  def advanced_stats_enabled?
    true
  end

  def report_visible_for_citizens?
    projekt_phase.feature?("resource.report_visible_for_citizens")
  end

  def evaluation_enabled?
    projekt_phase.feature?("resource.evaluation_enabled")
  end

  def show_open_answer_author_name?
    projekt_phase.feature?("resource.show_open_answer_author_name")
  end
end
