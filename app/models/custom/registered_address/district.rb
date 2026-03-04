class RegisteredAddress::District < ApplicationRecord
  include Mappable

  has_many :registered_addresses, dependent: :restrict_with_exception, inverse_of: :district,
    class_name: "RegisteredAddress", foreign_key: :registered_address_district_id
  belongs_to :default_deficiency_report_responsible, polymorphic: true
  belongs_to :default_idea_officer, class_name: "Idea::Officer", foreign_key: :idea_officer_id, optional: true

  has_many :contained_map_locations, class_name: "MapLocation",
                                     foreign_key: :registered_address_district_id,
                                     inverse_of: :district,
                                     dependent: :nullify

  has_and_belongs_to_many :affiliated_projekts,
    class_name: "Projekt",
    join_table: "projekts_registered_address_districts",
    foreign_key: "registered_address_district_id",
    association_foreign_key: "projekt_id"

  default_scope { order(name: :asc) }

  def self.table_name_prefix
    "registered_address_"
  end

  def district
    raise ArgumentError, "Can't call district on RegisteredAddress::District"
  end
end
