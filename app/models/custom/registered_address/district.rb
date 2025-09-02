class RegisteredAddress::District < ApplicationRecord
  include Mappable

  has_many :registered_addresses, dependent: :restrict_with_exception, inverse_of: :district,
    class_name: "RegisteredAddress", foreign_key: :registered_address_district_id
  belongs_to :default_deficiency_report_responsible, polymorphic: true
  belongs_to :default_idea_officer, class_name: "Idea::Officer", foreign_key: :idea_officer_id, optional: true

  default_scope { order(name: :asc) }

  def self.table_name_prefix
    "registered_address_"
  end
end
