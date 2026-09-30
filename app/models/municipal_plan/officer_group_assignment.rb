class MunicipalPlan::OfficerGroupAssignment < ApplicationRecord
  belongs_to :officer, class_name: "MunicipalPlan::Officer",
    foreign_key: :municipal_plan_officer_id, inverse_of: :officer_group_assignments
  belongs_to :officer_group, class_name: "MunicipalPlan::OfficerGroup",
    foreign_key: :municipal_plan_officer_group_id, inverse_of: :officer_group_assignments

  validates :municipal_plan_officer_id, uniqueness: { scope: :municipal_plan_officer_group_id }
end
