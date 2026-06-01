module Masterportal
  module FeaturePropertyReader
    REGENSBURG_BOUNDING_BOX = [12.024365, 48.962909, 12.198046, 49.080493].freeze

    TITLE_KEYS = %w[NAME BEZEICHNUNG TITLE TITEL].freeze
    CATEGORY_KEYS = %w[KATEGORIE ART_NAME ART_CATEGORY].freeze
    STREET_KEYS = %w[STRASSE STRASSENNAME STRASSE_NAME].freeze
    HOUSE_NUMBER_KEYS = %w[HAUS_NR HAUSNUMMER].freeze
    HOUSE_NUMBER_SUFFIX_KEYS = %w[HAUS_NR_ZUSATZ].freeze
    POSTCODE_KEYS = %w[PLZ POSTCODE].freeze
    CITY_KEYS = %w[ORT CITY STADT].freeze
    PHONE_KEYS = %w[TEL_NR TELEFON PHONE].freeze
    FAX_KEYS = %w[FAX_NR].freeze
    EMAIL_KEYS = %w[E_MAIL_ADRESSE EMAIL].freeze
    WEBSITE_KEYS = %w[INTERNET HOMEPAGE WEBSITE].freeze
    DESCRIPTION_KEYS = %w[LAGEBESCHREIBUNG BESCHREIBUNG DESCRIPTION].freeze

    ACCESSIBILITY_KEYS = %w[
      ZUGAENGLICH_VOLL ZUGAENGLICH_EINGESCHRAENKT ZUGAENGLICH_NICHT
      ZUGAENGLICH_BEGLEITPERSON ROLLSTUHL_PARKPLATZ ROLLSTUHL_WC
      HOERANLAGE_IND INFO_BLINDENSCHRIFT INFO_GEBAERDENSPRACHE
      INFO_LEICHTE_SPRACHE WELTERBERELEVANT
    ].freeze

    FALSY_STRINGS = %w[0 false nein no].freeze

    module_function

    def external_id(feature)
      props = feature["properties"] || {}

      props["FID"].presence || feature["id"].to_s.presence
    end

    def title(feature)
      title_value(feature) || external_id(feature)
    end

    def title_value(feature)
      value_from(feature["properties"] || {}, TITLE_KEYS)
    end

    def title_source_key(properties)
      props = properties || {}

      TITLE_KEYS.find { |key| props[key].to_s.strip.present? } ||
        CATEGORY_KEYS.find { |key| props[key].to_s.strip.present? }
    end

    def category_name(feature)
      value_from(feature["properties"] || {}, CATEGORY_KEYS)
    end

    def description(feature)
      props = feature["properties"] || {}
      sections = []

      address = address_line(props)
      sections << address if address.present?

      postcode_city = [value_from(props, POSTCODE_KEYS), value_from(props, CITY_KEYS)]
        .compact.join(" ").presence
      sections << postcode_city if postcode_city.present?

      category = value_from(props, CATEGORY_KEYS)
      sections << "#{I18n.t("masterportal.feature.category_label", default: "Kategorie")}: #{category}" if category.present?

      location_note = value_from(props, DESCRIPTION_KEYS)
      sections << location_note if location_note.present?

      contact = contact_block(props)
      sections << contact if contact.present?

      sections.join("\n").presence
    end

    def latitude(feature)
      coords = feature.dig("geometry", "coordinates")

      coords.is_a?(Array) ? coords[1].to_f : nil
    end

    def longitude(feature)
      coords = feature.dig("geometry", "coordinates")

      coords.is_a?(Array) ? coords[0].to_f : nil
    end

    def inside_regensburg_bbox?(feature)
      lon = longitude(feature)
      lat = latitude(feature)
      return false if lon.nil? || lat.nil?

      min_lon, min_lat, max_lon, max_lat = REGENSBURG_BOUNDING_BOX
      lon.between?(min_lon, max_lon) && lat.between?(min_lat, max_lat)
    end

    def truthy?(value)
      return false if value.nil?

      normalized = value.to_s.strip
      return false if normalized.empty?
      return false if FALSY_STRINGS.include?(normalized.downcase)

      true
    end

    def value_from(props, keys)
      keys.each do |key|
        value = props[key]
        return value.to_s.strip.presence if value.present?
      end

      nil
    end

    def address_line(props)
      street = value_from(props, STREET_KEYS)
      return nil if street.blank?

      house = value_from(props, HOUSE_NUMBER_KEYS)
      suffix = value_from(props, HOUSE_NUMBER_SUFFIX_KEYS)
      parts = [street, [house, suffix].compact.join("").presence].compact

      parts.join(" ")
    end

    def contact_block(props)
      items = []
      phone = value_from(props, PHONE_KEYS)
      fax = value_from(props, FAX_KEYS)
      email = value_from(props, EMAIL_KEYS)
      website = value_from(props, WEBSITE_KEYS)

      items << "Tel: #{phone}" if phone.present?
      items << "Fax: #{fax}" if fax.present?
      items << "E-Mail: #{email}" if email.present?
      items << "Web: #{website}" if website.present?

      items.join("\n").presence
    end
  end
end
