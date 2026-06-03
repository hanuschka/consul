class Shared::MasterportalPinPropertiesComponent < ApplicationComponent
  def initialize(masterportal_pin:)
    @pin = masterportal_pin
  end

  private

    attr_reader :pin

    def render?
      rows.any? || address_value.present?
    end

    def rows
      @rows ||= properties_hash.reject do |key, value|
        excluded_key?(key) || value.to_s.strip.empty?
      end
    end

    def excluded_key?(key)
      Masterportal::FeaturePropertyReader.technical_key?(key) ||
        key.to_s == title_key ||
        address_component_keys.include?(key.to_s)
    end

    def title_key
      @title_key ||= Masterportal::FeaturePropertyReader.title_source_key(properties_hash)
    end

    def label_for(key)
      Masterportal::FeaturePropertyReader.label_for(key)
    end

    def address_label
      Masterportal::FeaturePropertyReader.label_for("ADDRESS")
    end

    def address_value
      return @address_value if defined?(@address_value)

      line = Masterportal::FeaturePropertyReader.address_line(properties_hash)
      @address_value = [line, post_city].compact_blank.join(", ").presence
    end

    def post_city
      fpr = Masterportal::FeaturePropertyReader
      [fpr.value_from(properties_hash, fpr::POSTCODE_KEYS),
       fpr.value_from(properties_hash, fpr::CITY_KEYS)].compact.join(" ").presence
    end

    def address_component_keys
      @address_component_keys ||= begin
        fpr = Masterportal::FeaturePropertyReader
        fpr::STREET_KEYS + fpr::HOUSE_NUMBER_KEYS + fpr::HOUSE_NUMBER_SUFFIX_KEYS +
          fpr::POSTCODE_KEYS + fpr::CITY_KEYS + fpr::ADDRESS_KEYS
      end
    end

    def value_kind(key, value)
      text = value.to_s.strip

      return :accessibility if accessibility_key?(key)
      return :image if image_key?(key)
      return :phone if phone_key?(key)
      return :email if email_key?(key)
      return :url if website_key?(key) || url?(text)
      return :boolean if boolean_value?(text)

      :text
    end

    def truthy?(value)
      Masterportal::FeaturePropertyReader.truthy?(value)
    end

    def accessibility_key?(key)
      Masterportal::FeaturePropertyReader::ACCESSIBILITY_KEYS.include?(key)
    end

    def phone_key?(key)
      Masterportal::FeaturePropertyReader::PHONE_KEYS.include?(key) ||
        Masterportal::FeaturePropertyReader::FAX_KEYS.include?(key)
    end

    def email_key?(key)
      Masterportal::FeaturePropertyReader::EMAIL_KEYS.include?(key)
    end

    def website_key?(key)
      Masterportal::FeaturePropertyReader::WEBSITE_KEYS.include?(key)
    end

    def image_key?(key)
      Masterportal::FeaturePropertyReader::IMAGE_KEYS.include?(key)
    end

    def url?(text)
      text.match?(/\Ahttps?:\/\//i) || text.match?(/\Awww\./i)
    end

    def boolean_value?(text)
      %w[true false ja nein yes no].include?(text.downcase)
    end

    def url_with_protocol(text)
      text.match?(/\Ahttps?:\/\//i) ? text : "https://#{text}"
    end

    def properties_hash
      @properties_hash ||= pin.properties || {}
    end
end
