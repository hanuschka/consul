class Masterportal::GeocoderDataBuilder < ApplicationService
  def initialize(pin:)
    @pin = pin
  end

  def call
    {
      "street" => value_from(Masterportal::FeaturePropertyReader::STREET_KEYS),
      "city" => value_from(Masterportal::FeaturePropertyReader::CITY_KEYS),
      "postal_code" => value_from(Masterportal::FeaturePropertyReader::POSTCODE_KEYS)
    }.compact
  end

  private

    def value_from(keys)
      Masterportal::FeaturePropertyReader.value_from(@pin.properties || {}, keys)
    end
end
