class ProjektPointOfInterestPin < ApplicationRecord
  include Mappable

  belongs_to :projekt_phase
  belongs_to :author, class_name: "User", optional: true
  belongs_to :api_client_created, class_name: 'ApiClient', optional: true
  belongs_to :api_client_last_updated, class_name: 'ApiClient', optional: true

  scope :ordered, -> { order(created_at: :desc) }
  scope :by_categories, -> (category_ids) {
    return if category_ids.blank?

    where(projekt_point_of_interest_category_id: category_ids)
  }

  validates :author, presence: true, unless: :api_context?
  validates :api_client_created, presence: true, on: :api
  validate :validate_max_point_of_interest_pins_per_user

  def api_context?
    validation_context == :api
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
