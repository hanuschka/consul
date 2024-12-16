class DeficiencyReport::OfficerGroupAssignment < ApplicationRecord
  belongs_to :officer, class_name: "DeficiencyReport::Officer", foreign_key: "deficiency_report_officer_id"
  belongs_to :officer_group, class_name: "DeficiencyReport::OfficerGroup", foreign_key: "deficiency_report_officer_group_id"
end
