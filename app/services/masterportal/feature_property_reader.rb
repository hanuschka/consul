module Masterportal
  module FeaturePropertyReader
    REGENSBURG_BOUNDING_BOX = [12.024365, 48.962909, 12.198046, 49.080493].freeze

    TITLE_KEYS = %w[NAME BEZEICHNUNG TITLE TITEL].freeze
    CATEGORY_KEYS = %w[KATEGORIE ART_NAME ART_CATEGORY].freeze
    STREET_KEYS = %w[STRASSE STRASSENNAME STRASSE_NAME].freeze
    HOUSE_NUMBER_KEYS = %w[HAUS_NR HAUSNUMMER].freeze
    HOUSE_NUMBER_SUFFIX_KEYS = %w[HAUS_NR_ZUSATZ].freeze
    ADDRESS_KEYS = %w[ADRESSE].freeze
    POSTCODE_KEYS = %w[PLZ POSTCODE].freeze
    CITY_KEYS = %w[ORT CITY STADT].freeze
    PHONE_KEYS = %w[TEL_NR TELEFON PHONE].freeze
    FAX_KEYS = %w[FAX_NR].freeze
    EMAIL_KEYS = %w[E_MAIL_ADRESSE EMAIL].freeze
    WEBSITE_KEYS = %w[INTERNET HOMEPAGE WEBSITE].freeze
    DESCRIPTION_KEYS = %w[LAGEBESCHREIBUNG ALG_LAGEBESCHREIBUNG BESCHREIBUNG DESCRIPTION].freeze
    OPENING_HOURS_KEYS = %w[OEFFNUNGSZEITEN].freeze
    OPERATOR_KEYS = %w[TRAEGER].freeze
    PRICE_KEYS = %w[PREIS].freeze
    IMAGE_KEYS = %w[IMAGE].freeze

    ACCESSIBILITY_KEYS = %w[
      ZUGAENGLICH_VOLL ZUGAENGLICH_EINGESCHRAENKT ZUGAENGLICH_NICHT
      ZUGAENGLICH_BEGLEITPERSON ROLLSTUHL_PARKPLATZ ROLLSTUHL_WC
      HOERANLAGE_IND INFO_BLINDENSCHRIFT INFO_GEBAERDENSPRACHE
      INFO_LEICHTE_SPRACHE WELTERBERELEVANT
      VALUE_BARRIEREFREI VALUE_SITZMOEGLICHKEITEN
      BAR_VOLL_ZUGAENGLICH BAR_EING_ZUGAENGLICH
      BAR_NICHT_ZUGAENGLICH BAR_BEGLEITPERS_ZUGAENGLICH
    ].freeze

    TECHNICAL_KEYS = %w[
      FID OBJID OBJIID DATAID ART_ID BEMERKUNG DENKMAL_ID BILD_NAME IMAGE IMAGE_URL
      FLAECHE X_KOORDINATE Y_KOORDINATE DATE_TIME_UPDATE LAST_UPDATE
    ].freeze

    TECHNICAL_KEY_PREFIX = "Q__"

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

    def opening_hours(props)
      value_from(props, OPENING_HOURS_KEYS)
    end

    def operator(props)
      value_from(props, OPERATOR_KEYS)
    end

    def price(props)
      value_from(props, PRICE_KEYS)
    end

    def image_url(props)
      value_from(props, IMAGE_KEYS)
    end

    def technical_key?(key)
      normalized = key.to_s.upcase
      return true if normalized.start_with?(TECHNICAL_KEY_PREFIX)

      TECHNICAL_KEYS.include?(normalized)
    end

    def label_for(key)
      flag_label = I18n.t("masterportal.accessibility_flags.#{key}", default: nil)

      return flag_label if flag_label.present?

      I18n.t("masterportal.popup.property_labels.#{key.to_s.downcase}", default: humanize_key(key))
    end

    def humanize_key(key)
      key.to_s.tr("_", " ").downcase.gsub(/\b\w/, &:upcase)
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

    def geometry(feature)
      feature["geometry"].presence
    end

    def latitude(feature)
      point = representative_point(feature)

      point.is_a?(Array) ? point[1].to_f : nil
    end

    def longitude(feature)
      point = representative_point(feature)

      point.is_a?(Array) ? point[0].to_f : nil
    end

    def representative_point(feature)
      geometry = feature["geometry"] || {}
      coordinates = geometry["coordinates"]
      return nil if coordinates.blank?

      return coordinates if geometry["type"] == "Point"

      centroid_coordinates(geometry)
    end

    def centroid_coordinates(geometry)
      rings = exterior_rings(geometry)
      return nil if rings.empty?

      weighted_x = 0.0
      weighted_y = 0.0
      total_area = 0.0

      rings.each do |ring|
        area, ring_x, ring_y = ring_centroid(ring)
        weighted_x += ring_x * area
        weighted_y += ring_y * area
        total_area += area
      end

      return vertices_average(rings) if total_area.zero?

      [weighted_x / total_area, weighted_y / total_area]
    end

    def exterior_rings(geometry)
      case geometry["type"]
      when "Polygon"
        [Array(geometry["coordinates"])[0]].compact
      when "MultiPolygon"
        Array(geometry["coordinates"]).map { |polygon| polygon[0] }.compact
      else
        []
      end
    end

    def ring_centroid(ring)
      points = Array(ring)
      return [0.0, 0.0, 0.0] if points.size < 3

      signed_area = 0.0
      centroid_x = 0.0
      centroid_y = 0.0

      points.each_with_index do |point, index|
        x0, y0 = point
        x1, y1 = points[(index + 1) % points.size]
        cross = (x0 * y1) - (x1 * y0)
        signed_area += cross
        centroid_x += (x0 + x1) * cross
        centroid_y += (y0 + y1) * cross
      end

      signed_area /= 2.0
      return [0.0, 0.0, 0.0] if signed_area.zero?

      [signed_area.abs, centroid_x / (6.0 * signed_area), centroid_y / (6.0 * signed_area)]
    end

    def vertices_average(rings)
      points = rings.flatten(1)
      return nil if points.empty?

      sum_x = points.sum { |point| point[0].to_f }
      sum_y = points.sum { |point| point[1].to_f }

      [sum_x / points.size, sum_y / points.size]
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
      return value_from(props, ADDRESS_KEYS) if street.blank?

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
