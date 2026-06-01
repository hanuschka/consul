class Shared::MasterportalPinPropertiesComponent < ApplicationComponent
  def initialize(masterportal_pin:)
    @pin = masterportal_pin
  end

  private

    attr_reader :pin

    def render?
      rows.any?
    end

    EXCLUDED_KEYS = %w[FID ART_ID].freeze

    def rows
      @rows ||= (pin.properties || {}).reject do |key, value|
        excluded_key?(key) || value.to_s.strip.empty?
      end
    end

    def excluded_key?(key)
      EXCLUDED_KEYS.include?(key.to_s) || key.to_s == title_key
    end

    def title_key
      @title_key ||= Masterportal::FeaturePropertyReader.title_property_key(pin.properties || {})
    end

    def label_for(key)
      key.to_s.tr("_", " ")
    end

    def value_kind(key, value)
      text = value.to_s.strip

      return :accessibility if accessibility_key?(key)
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

    def url?(text)
      text.match?(/\Ahttps?:\/\//i) || text.match?(/\Awww\./i)
    end

    def boolean_value?(text)
      %w[true false ja nein yes no].include?(text.downcase)
    end

    def url_with_protocol(text)
      text.match?(/\Ahttps?:\/\//i) ? text : "https://#{text}"
    end
end
