class Shared::MasterportalPinInfoComponent < ApplicationComponent
  def initialize(masterportal_pin:)
    @pin = masterportal_pin
  end

  private

    attr_reader :pin

    def render?
      any_detail?
    end

    def category
      Masterportal::FeaturePropertyReader.category_name(feature_shell)
    end

    def address_line
      Masterportal::FeaturePropertyReader.address_line(properties)
    end

    def post_city
      postcode = value_for(Masterportal::FeaturePropertyReader::POSTCODE_KEYS)
      city = value_for(Masterportal::FeaturePropertyReader::CITY_KEYS)

      [postcode, city].compact.join(" ").presence
    end

    def phone
      value_for(Masterportal::FeaturePropertyReader::PHONE_KEYS)
    end

    def fax
      value_for(Masterportal::FeaturePropertyReader::FAX_KEYS)
    end

    def email
      value_for(Masterportal::FeaturePropertyReader::EMAIL_KEYS)
    end

    def website
      value_for(Masterportal::FeaturePropertyReader::WEBSITE_KEYS)
    end

    def location_note
      value_for(Masterportal::FeaturePropertyReader::DESCRIPTION_KEYS)
    end

    def accessibility_flags
      Masterportal::FeaturePropertyReader::ACCESSIBILITY_KEYS.select do |key|
        Masterportal::FeaturePropertyReader.truthy?(properties[key])
      end
    end

    def contact_present?
      phone.present? || fax.present? || email.present? || website.present?
    end

    def any_detail?
      category.present? || address_line.present? || post_city.present? ||
        contact_present? || location_note.present? || accessibility_flags.any?
    end

    def value_for(keys)
      Masterportal::FeaturePropertyReader.value_from(properties, keys)
    end

    def properties
      @properties ||= pin.properties || {}
    end

    def feature_shell
      { "properties" => properties }
    end
end
