class ProjektPointOfInterestPin < ApplicationRecord
  include NewMappable

  belongs_to :projekt_phase
  belongs_to :author, class_name: "User"
  belongs_to :projekt_point_of_interest_category

  scope :ordered, -> { order(created_at: :desc) }

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

  def pin_json_data
    {
      lat: map_location.latitude,
      long: map_location.longitude,
      zoom: map_location.zoom,
      color: projekt_point_of_interest_category.color,
      fa_icon_class: projekt_point_of_interest_category.icon
    }
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
