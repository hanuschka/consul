class ProjektPointOfInterestPin < ApplicationRecord
  belongs_to :projekt_phase
  belongs_to :author, class_name: "User"
  belongs_to :projekt_point_of_interest_category
  has_one :map_location, as: :mappable, dependent: :destroy

  validates_associated :map_location

  scope :ordered, -> { order(created_at: :desc) }

  accepts_nested_attributes_for :map_location

  def latitude
    map_location&.latitude
  end

  def longitude
    map_location&.longitude
  end

  def zoom
    map_location&.zoom
  end

  def to_csv
    [
      id,
      title,
      description,
      latitude,
      longitude,
      projekt_point_of_interest_categories.map(&:name).join(", "),
      user.name,
      created_at,
      updated_at
    ]
  end

  def self.to_csv
    CSV.generate do |csv|
      csv << ["ID", "Title", "Description", "Latitude", "Longitude", "Categories", "User", "Created At", "Updated At"]
      all.each do |pin|
        csv << pin.to_csv
      end
    end
  end
end
