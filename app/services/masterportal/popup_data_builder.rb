class Masterportal::PopupDataBuilder < ApplicationService
  EXCLUDED_KEYS = %w[FID].freeze
  PHONE_KEY_PATTERN = /\A(TEL|TELEFON|PHONE|FAX)/i
  URL_KEY_PATTERN = /\A(INTERNET|HOMEPAGE|WEBSITE|URL|WEB)/i
  EMAIL_KEY_PATTERN = /(MAIL|EMAIL)/i

  def initialize(pin:)
    @pin = pin
  end

  def call
    rows = []
    rows << combined_address_row if address_keys_present?

    enumerable_properties.each do |key, value|
      rows << build_row(key, value)
    end

    rows.compact
  end

  private

    def enumerable_properties
      @pin.properties.to_h.reject { |key, value| skip_entry?(key, value) }
    end

    def skip_entry?(key, value)
      return true if value.blank?
      return true if value.to_s.strip == "0"
      return true if EXCLUDED_KEYS.include?(key.to_s.upcase)
      return true if combined_address_keys.include?(key.to_s.upcase)

      false
    end

    def combined_address_keys
      %w[STRASSE HAUS_NR HAUS_NR_ZUSATZ PLZ ORT]
    end

    def address_keys_present?
      combined_address_keys.any? { |k| @pin.properties[k].to_s.strip.present? }
    end

    def combined_address_row
      props = @pin.properties.to_h
      street_parts = [props["STRASSE"], [props["HAUS_NR"], props["HAUS_NR_ZUSATZ"]].compact_blank.join]
      city_parts = [props["PLZ"], props["ORT"]]
      address_value = [street_parts.compact_blank.join(" "), city_parts.compact_blank.join(" ")].compact_blank.join(", ")

      return nil if address_value.blank?

      {
        "key" => "ADDRESS",
        "label" => I18n.t("masterportal.popup.property_labels.address", default: "Adresse"),
        "value" => address_value,
        "type" => "text"
      }
    end

    def build_row(key, value)
      {
        "key" => key,
        "label" => label_for(key),
        "value" => format_value(value),
        "type" => detect_type(key, value)
      }
    end

    def label_for(key)
      flag_label = I18n.t("masterportal.accessibility_flags.#{key}", default: nil)

      return flag_label if flag_label.present?

      I18n.t(
        "masterportal.popup.property_labels.#{key.downcase}",
        default: humanize_key(key)
      )
    end

    def humanize_key(key)
      key.to_s.tr("_", " ").downcase.gsub(/\b\w/, &:upcase)
    end

    def detect_type(key, value)
      return "email" if email_value?(key, value)
      return "url" if url_value?(key, value)
      return "phone" if phone_value?(key, value)
      return "yes_no" if yes_value?(value)

      "text"
    end

    def email_value?(key, value)
      return true if key.to_s.match?(EMAIL_KEY_PATTERN)

      value.to_s.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def url_value?(key, value)
      return true if key.to_s.match?(URL_KEY_PATTERN) && value.to_s.strip.present?

      value.to_s.strip.match?(/\Ahttps?:\/\//i)
    end

    def phone_value?(key, value)
      key.to_s.match?(PHONE_KEY_PATTERN) && value.to_s.strip.present?
    end

    def yes_value?(value)
      value.to_s.strip == "1"
    end

    def format_value(value)
      stripped = value.to_s.strip
      return I18n.t("masterportal.popup.value_yes", default: "Ja") if stripped == "1"

      stripped
    end
end
