class RegisteredAddressDistrictProjektPhase < ApplicationRecord
  belongs_to :registered_address_district, class_name: "RegisteredAddress::District",
                                           foreign_key: "registered_address_district_id"
  belongs_to :projekt_phase
end
