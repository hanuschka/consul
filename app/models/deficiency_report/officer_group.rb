class DeficiencyReport::OfficerGroup < ApplicationRecord
  has_many :officer_group_assignments, class_name: "DeficiencyReport::OfficerGroupAssignment",
    foreign_key: "deficiency_report_officer_group_id", dependent: :destroy
  has_many :officers, through: :officer_group_assignments, class_name: "DeficiencyReport::Officer"
end
