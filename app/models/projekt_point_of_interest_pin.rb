class ProjektPointOfInterestPin < ApplicationRecord
  include NewMappable

  belongs_to :projekt_phase
  belongs_to :author, class_name: "User"
  belongs_to :projekt_point_of_interest_category, optional: false

  scope :ordered, -> { order(created_at: :desc) }
  scope :by_categories, -> (category_ids) {
    return if category_ids.blank?

    where(projekt_point_of_interest_category_id: category_ids)
  }

  validate :validate_max_point_of_interest_pins_per_user

  def pin_json_data
    {
      id: id,
      resource_type: "point_of_interest_pin",
      projekt_phase_id: projekt_phase.id,
      lat: map_location.latitude,
      long: map_location.longitude,
      zoom: map_location.zoom,
      color: projekt_point_of_interest_category.color,
      fa_icon_class: projekt_point_of_interest_category.icon
    }
  end

  private

  def validate_max_point_of_interest_pins_per_user
    max_pins_per_user_value = projekt_phase.settings.find_by(key: "option.general.max_number_of_pins_per_user")&.value
    max_pins_per_user_int = Integer(max_pins_per_user_value) rescue nil

    if max_pins_per_user_int.present?
      number_of_pins_created_by_author = projekt_phase.projekt_point_of_interest_pins.where(author_id: author_id).count

      if number_of_pins_created_by_author >= max_pins_per_user_value.to_i
        errors.add(
          :base,
          "Maximale Anzahl von Pins pro Benutzer. Sie können für den aktuellen Benutzer nicht mehr als #{max_pins_per_user_value} hinzufügen."
        )
      end
    end
  end
end
