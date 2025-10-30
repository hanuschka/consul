class ProjektPointOfInterestPinSerializer < BaseSerializer
  attr_reader :pin

  def initialize(pin)
    @pin = pin
  end

  def serialize
    pin_data = pin.as_json(
      only: [
        :id,
        :author_id,
        :projekt_point_of_interest_category_id,
        :description,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

    if pin.author.present?
      pin_data[:author] = {
        id: pin.author.id,
        username: pin.author.username,
        public_name: pin.author.public_name
      }
    end

    if pin.respond_to?(:projekt_point_of_interest_category) && pin.projekt_point_of_interest_category.present?
      pin_data[:category] = {
        id: pin.projekt_point_of_interest_category.id,
        name: pin.projekt_point_of_interest_category.name,
        color: pin.projekt_point_of_interest_category.color,
        icon: pin.projekt_point_of_interest_category.icon
      }
    end

    if pin.projekt_phase.present?
      pin_data[:projekt_phase] = {
        id: pin.projekt_phase.id,
        title: pin.projekt_phase.phase_tab_name,
        type: pin.projekt_phase.type,
        projekt_id: pin.projekt_phase.projekt_id
      }

      if pin.projekt_phase.projekt.present?
        projekt = pin.projekt_phase.projekt
        pin_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    if pin.map_location.present?
      pin_data[:map_location] = {
        latitude: pin.map_location.latitude,
        longitude: pin.map_location.longitude,
        zoom: pin.map_location.zoom
      }
    end

    pin_data
  end

  def self.serialize_collection(pins)
    pins.map { |pin| new(pin).serialize }
  end
end

