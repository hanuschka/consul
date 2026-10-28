class DeficiencyReport::ManagementReport < ApplicationRecord
  belongs_to :report_profile, class_name: "DeficiencyReport::ReportProfile"

  enum status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }

  enum trigger: {
    manual: "manual",
    scheduled: "scheduled"
  }

  validates :profile_name, :period_start, :period_end, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
  scope :sent, -> { where.not(sent_at: nil) }

  def self.start_for(profile, trigger:, now: Time.current)
    create!(
      report_profile: profile,
      profile_name: profile.name,
      building_blocks: profile.building_blocks,
      period_start: profile.next_period_start(now),
      period_end: now,
      trigger: trigger
    ).tap(&:generate_later)
  end

  def generate_later
    DeficiencyReports::GenerateManagementReportJob.perform_later(id)
  end

  def period
    period_start..period_end
  end

  def section_for(building_block)
    sections.find { |section| section["building_block"] == building_block }
  end

  def statements_for(building_block)
    section_for(building_block)&.fetch("statements", []) || []
  end

  def figure_rows(building_block)
    data = figures[building_block]
    return [] if data.blank?

    scope = "adm.deficiency_reports.management_reports.figures"

    case building_block
    when "incoming_and_closed"
      [{ label: I18n.t("#{scope}.incoming"), value: data["incoming"] },
       { label: I18n.t("#{scope}.closed"), value: data["closed"] }]
    when "open_and_overdue"
      [{ label: I18n.t("#{scope}.open"), value: data["open"] },
       { label: I18n.t("#{scope}.overdue"), value: data["overdue"] }]
    when "status_overview", "top_categories"
      data.map { |row| { label: row["name"], value: row["count"] } }
    when "notable_items"
      data.map do |row|
        { label: row["title"], report_id: row["id"],
          value: [I18n.t("#{scope}.comments", count: row["comments"]), I18n.t("#{scope}.supports", count: row["supports"])].join(", ") }
      end
    else
      []
    end
  end
end
