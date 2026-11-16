require "csv"

module Offers
  class CsvImport < ApplicationService
    COLUMNS = %i[
      provider title short_description times costs registration address
      contact_name contact_phone contact_email contact_website expires_on latitude longitude
      offer_type target_group costs_category accessibility social_area
    ].freeze
    REQUIRED_COLUMNS = %i[provider title short_description offer_type social_area].freeze
    CATEGORY_COLUMNS = {
      offer_type: "offer_type", target_group: "target_group", costs_category: "costs",
      accessibility: "accessibility", social_area: "social_area"
    }.freeze
    TEXT_ATTRIBUTES = %i[address contact_name contact_phone contact_email contact_website].freeze
    TRANSLATED_ATTRIBUTES = %i[title times costs registration].freeze
    VALUE_SEPARATOR = ",".freeze
    MAX_ROWS = 500
    MAP_ZOOM = 15

    Row = Struct.new(:line, :title, :offer, :errors, keyword_init: true) do
      def created?
        offer.present?
      end
    end
    Result = Struct.new(:rows, :file_errors, keyword_init: true) do
      def created_count
        rows.count(&:created?)
      end

      def failed_count
        rows.count { |row| !row.created? }
      end
    end

    def self.headers
      COLUMNS.map { |column| I18n.t("adm.offers.imports.columns.#{column}", locale: I18n.default_locale) }
    end

    def self.template
      "\uFEFF" + CSV.generate_line(headers, col_sep: ";")
    end

    def initialize(content, author:)
      @content = utf8(content.to_s).delete_prefix("\uFEFF")
      @author = author
    end

    def call
      table = parse
      return Result.new(rows: [], file_errors: [t("errors.unreadable")]) if table.nil?

      missing = missing_columns(table.headers)
      return Result.new(rows: [], file_errors: [t("errors.missing_columns", columns: missing.join(", "))]) if missing.any?
      return Result.new(rows: [], file_errors: [t("errors.too_many_rows", max: MAX_ROWS)]) if table.size > MAX_ROWS

      rows = table.each.with_index(2).reject { |row, _| row.fields.all?(&:blank?) }.map do |row, line|
        import_row(normalized(row), line)
      end

      Result.new(rows: rows, file_errors: [])
    end

    private

      attr_reader :content, :author

      def parse
        return if content.blank?

        CSV.parse(content, headers: true, col_sep: column_separator, skip_blanks: true)
      rescue CSV::MalformedCSVError
        nil
      end

      def column_separator
        header_line = content.lines.first.to_s
        header_line.count(";") >= header_line.count(",") ? ";" : ","
      end

      def header_keys
        @header_keys ||= COLUMNS.zip(self.class.headers).to_h { |key, header| [normalize_header(header), key] }
      end

      def normalize_header(header)
        header.to_s.strip.downcase
      end

      def missing_columns(headers)
        present = headers.compact.map { |header| header_keys[normalize_header(header)] }
        (REQUIRED_COLUMNS - present).map { |column| I18n.t("adm.offers.imports.columns.#{column}") }
      end

      def normalized(row)
        row.each_with_object({}) do |(header, value), values|
          key = header_keys[normalize_header(header)]
          values[key] = value.to_s.strip if key
        end
      end

      def import_row(values, line)
        errors = []
        provider = find_provider(values[:provider], errors)
        categories = find_categories(values, errors)
        expires_on = parse_date(values[:expires_on], errors)
        map_location = parse_location(values, errors)

        return Row.new(line: line, title: values[:title], errors: errors) if errors.any?

        offer = build_offer(values, provider, categories, expires_on, map_location)

        if offer.save
          Row.new(line: line, title: values[:title], offer: offer, errors: [])
        else
          Row.new(line: line, title: values[:title], errors: offer.errors.full_messages)
        end
      end

      def build_offer(values, provider, categories, expires_on, map_location)
        Globalize.with_locale(I18n.default_locale) do
          offer = Offer.new(values.slice(*TEXT_ATTRIBUTES, *TRANSLATED_ATTRIBUTES).compact_blank)
          offer.short_description = html_paragraphs(values[:short_description])
          offer.assign_attributes(author: author, provider: provider, expires_on: expires_on)
          categories.each { |category| offer.category_assignments.build(category: category) }
          offer.build_map_location(map_location) if map_location
          offer
        end
      end

      def find_provider(name, errors)
        return if name.blank?

        matches = providers_by_name.fetch(name.downcase, [])
        errors << t("errors.unknown_provider", name: name) if matches.empty?
        errors << t("errors.ambiguous_provider", name: name) if matches.many?
        matches.first if matches.one?
      end

      def providers_by_name
        @providers_by_name ||= Offer::Provider.all.group_by { |provider| provider.name.to_s.strip.downcase }
      end

      def find_categories(values, errors)
        CATEGORY_COLUMNS.flat_map do |column, kind|
          values[column].to_s.split(VALUE_SEPARATOR).map(&:strip).compact_blank.filter_map do |name|
            category = categories_by_kind_and_name[[kind, name.downcase]]
            if category.nil?
              errors << t("errors.unknown_category", name: name,
                                                     kind: I18n.t("activerecord.attributes.offer/category.kinds.#{kind}"))
            end
            category
          end
        end.uniq
      end

      def categories_by_kind_and_name
        @categories_by_kind_and_name ||= Globalize.with_locale(I18n.default_locale) do
          Offer::Category.includes(:translations).to_h do |category|
            [[category.kind, category.name.to_s.strip.downcase], category]
          end
        end
      end

      def parse_date(value, errors)
        return if value.blank?

        Date.strptime(value, value.include?(".") ? "%d.%m.%Y" : "%Y-%m-%d")
      rescue Date::Error
        errors << t("errors.invalid_date", value: value)
        nil
      end

      def parse_location(values, errors)
        latitude, longitude = values.values_at(:latitude, :longitude)
        return if latitude.blank? && longitude.blank?

        coordinates = [latitude, longitude].map { |value| Float(value.to_s.tr(",", "."), exception: false) }
        if coordinates.any?(&:nil?)
          errors << t("errors.invalid_location")
          return
        end

        latitude, longitude = coordinates
        {
          latitude: latitude, longitude: longitude, zoom: MAP_ZOOM, skip_masterportal_geocoding: true,
          features: {
            type: "FeatureCollection",
            features: [{ type: "Feature", geometry: { type: "Point", coordinates: [longitude, latitude] },
                         properties: {} }]
          }
        }
      end

      def html_paragraphs(text)
        return if text.blank?

        text.split(/\R{2,}/).map { |paragraph| "<p>#{ERB::Util.html_escape(paragraph.strip).gsub(/\R/, "<br>")}</p>" }.join
      end

      def utf8(text)
        text = text.dup.force_encoding("UTF-8")
        text.valid_encoding? ? text : text.force_encoding("Windows-1252").encode("UTF-8")
      end

      def t(key, **options)
        I18n.t("adm.offers.imports.#{key}", **options)
      end
  end
end
