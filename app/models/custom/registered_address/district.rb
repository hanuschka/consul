class RegisteredAddress::District < ApplicationRecord
  has_many :registered_addresses, dependent: :restrict_with_exception, inverse_of: :district,
    class_name: "RegisteredAddress", foreign_key: :registered_address_district_id
  belongs_to :default_deficiency_report_responsible, polymorphic: true

  has_one :map_location, foreign_key: :registered_address_district_id,
    inverse_of: :registered_address_district, dependent: :destroy
  accepts_nested_attributes_for :map_location, update_only: true

  default_scope { order(name: :asc) }

  def self.table_name_prefix
    "registered_address_"
  end
end
