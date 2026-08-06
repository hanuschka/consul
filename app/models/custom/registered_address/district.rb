class RegisteredAddress::District < ApplicationRecord
  include Mappable

  has_many :registered_addresses, dependent: :restrict_with_exception, inverse_of: :district,
    class_name: "RegisteredAddress", foreign_key: :registered_address_district_id
  has_many :cities, -> { distinct }, through: :registered_addresses,
    class_name: "RegisteredAddress::City", source: :registered_address_city
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

  # Rendered once per district in every district filter list, so neither the
  # city count nor the city lookup may sit on the per-district path. Both are
  # resolved once per request instead of once per district.
  def name_for_display
    if self.class.multiple_cities?
      city_name = self.class.first_city_names[id]
      city_name ? "#{city_name} / #{name}" : name.to_s
    else
      name.to_s
    end
  end

  def self.multiple_cities?
    return Current.multiple_registered_address_cities if !Current.multiple_registered_address_cities.nil?

    Current.multiple_registered_address_cities = RegisteredAddress::City.count > 1
  end

  # district id => name of its lowest-id city, matching what the previous
  # per-district `cities.first` (ORDER BY id LIMIT 1) returned.
  def self.first_city_names
    Current.registered_address_first_city_names ||= begin
      city_names = RegisteredAddress::City.pluck(:id, :name).to_h

      RegisteredAddress
        .where.not(registered_address_city_id: nil)
        .group(:registered_address_district_id)
        .minimum(:registered_address_city_id)
        .transform_values { |city_id| city_names[city_id] }
    end
  end

  def district
    raise ArgumentError, "Can't call district on RegisteredAddress::District"
  end
end
