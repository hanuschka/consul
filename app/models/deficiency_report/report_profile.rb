class DeficiencyReport::ReportProfile < ApplicationRecord
  BUILDING_BLOCKS = %w[
    incoming_and_closed
    status_overview
    top_categories
    open_and_overdue
    frequent_topics
    notable_items
  ].freeze
  FREQUENCIES = %w[weekly monthly].freeze
  INSTRUCTIONS_MAX_LENGTH = 2000

  has_many :management_reports, class_name: "DeficiencyReport::ManagementReport", dependent: :destroy

  validates :name, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :hour, inclusion: { in: 0..23 }
  validates :weekday, inclusion: { in: 0..6 }, if: :weekly?
  validates :day_of_month, inclusion: { in: 1..28 }, if: :monthly?
  validates :instructions, length: { maximum: INSTRUCTIONS_MAX_LENGTH }
  validate :building_blocks_known_and_present
  validate :recipients_present
  validate :recipient_users_eligible
  validate :recipient_emails_valid

  before_validation :normalize_lists

  scope :active, -> { where(paused: false) }

  def self.eligible_recipients
    User.where(id: Administrator.select(:user_id))
        .or(User.where(id: DeficiencyReportManager.select(:user_id)))
        .or(User.where(id: DeficiencyReport::Officer.select(:user_id)))
        .order(:username)
  end

  def weekly?
    frequency == "weekly"
  end

  def monthly?
    frequency == "monthly"
  end

  def due_at?(time)
    return false unless time.hour == hour

    weekly? ? time.wday == weekday : time.day == day_of_month
  end

  def next_period_start(now = Time.current)
    management_reports.sent.maximum(:period_end) || (monthly? ? now - 1.month : now - 7.days)
  end

  def deficiency_reports
    reports = DeficiencyReport.all
    reports = reports.where(deficiency_report_category_id: category_ids) if category_ids.any?
    return reports if officer_group_ids.empty?

    member_officer_ids = DeficiencyReport::OfficerGroupAssignment
      .where(deficiency_report_officer_group_id: officer_group_ids)
      .select(:deficiency_report_officer_id)

    reports.where(responsible_type: "DeficiencyReport::OfficerGroup", responsible_id: officer_group_ids)
      .or(reports.where(responsible_type: "DeficiencyReport::Officer", responsible_id: member_officer_ids))
  end

  def recipient_users
    User.where(id: recipient_user_ids)
  end

  def recipient_emails_text
    recipient_emails.join("\n")
  end

  def recipient_emails_text=(text)
    self.recipient_emails = text.to_s.split(/[\s,;]+/)
  end

  private

    def normalize_lists
      self.building_blocks = building_blocks.reject(&:blank?).uniq
      self.category_ids = category_ids.reject(&:blank?).map(&:to_i).uniq
      self.officer_group_ids = officer_group_ids.reject(&:blank?).map(&:to_i).uniq
      self.recipient_user_ids = recipient_user_ids.reject(&:blank?).map(&:to_i).uniq
      self.recipient_emails = recipient_emails.map(&:strip).reject(&:blank?).map(&:downcase).uniq
      self.weekday = nil unless weekly?
      self.day_of_month = nil unless monthly?
    end

    def building_blocks_known_and_present
      if building_blocks.empty?
        errors.add(:building_blocks, :blank_selection)
      elsif (building_blocks - BUILDING_BLOCKS).any?
        errors.add(:building_blocks, :inclusion)
      end
    end

    def recipients_present
      return if recipient_user_ids.any? || recipient_emails.any?

      errors.add(:recipient_user_ids, :no_recipients)
    end

    def recipient_users_eligible
      return if recipient_user_ids.empty?
      return if self.class.eligible_recipients.where(id: recipient_user_ids).count == recipient_user_ids.size

      errors.add(:recipient_user_ids, :ineligible)
    end

    def recipient_emails_valid
      invalid = recipient_emails.reject { |email| email.match?(URI::MailTo::EMAIL_REGEXP) }
      return if invalid.empty?

      errors.add(:recipient_emails_text, :invalid_entries, count: invalid.size, entries: invalid.join(", "))
    end
end
