class DeficiencyReport::Officer < ApplicationRecord
  belongs_to :user
  has_many :deficiency_reports, foreign_key: :deficiency_report_officer_id, dependent: :nullify
  has_many :default_category_assignments, class_name: "DeficiencyReport::Category", foreign_key: :deficiency_report_officer_id, dependent: :nullify

  has_many :officer_group_assignments, class_name: "DeficiencyReport::OfficerGroupAssignment",
    foreign_key: :deficiency_report_officer_id, dependent: :destroy
  has_many :officer_groups, through: :officer_group_assignments

  def name
    user&.name || I18n.t("shared.author_info.author_deleted")
  end

  def email
    user&.email || I18n.t("shared.author_info.email_deleted")
  end
end
