class MunicipalPlan::DistrictAssignment < ApplicationRecord
  belongs_to :municipal_plan, inverse_of: :district_assignments
  belongs_to :district, class_name: "RegisteredAddress::District",
    foreign_key: :registered_address_district_id, inverse_of: false

  validates :registered_address_district_id, uniqueness: { scope: :municipal_plan_id }
end
