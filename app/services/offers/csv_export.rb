require "csv"

module Offers
  class CsvExport
    INFO_COLUMNS = %i[review_status visibility].freeze

    def self.call(offers)
      new(offers).call
    end

    def self.plain_text(html)
      return if html.blank?

      text = html.gsub(%r{<br\s*/?>}i, "\n").gsub(%r{</p>}i, "\n\n")
      text = Rails::Html::FullSanitizer.new.sanitize(text)
      HTMLEntities.new.decode(text).gsub(/[ \t]+\n/, "\n").gsub(/\n{3,}/, "\n\n").strip
    end

    def initialize(offers)
      @offers = offers
    end

    def call
      I18n.with_locale(I18n.default_locale) do
        Globalize.with_locale(I18n.default_locale) do
          "\uFEFF" + CSV.generate(col_sep: ";") do |csv|
            csv << headers
            @offers.each { |offer| csv << row(offer).map { |value| guard_formula(value) } }
          end
        end
      end
    end

    private

      def headers
        [CsvImport.id_header] + CsvImport.headers +
          INFO_COLUMNS.map { |column| I18n.t("adm.offers.offers.index.table.#{column}") }
      end

      def row(offer)
        values = import_values(offer)
        [offer.id] + CsvImport::COLUMNS.map { |column| values[column] } +
          [I18n.t("adm.offers.offers.index.review_status.#{offer.review_status}"), visibility(offer)]
      end

      def import_values(offer)
        coordinates = offer.map_location&.pin_coordinates || {}

        {
          provider: offer.provider&.name,
          title: offer.title,
          short_description: self.class.plain_text(offer.short_description),
          times: offer.times,
          costs: offer.costs,
          registration: offer.registration,
          address: offer.address,
          contact_name: offer.contact_name,
          contact_phone: offer.contact_phone,
          contact_email: offer.contact_email,
          contact_website: offer.contact_website,
          expires_on: offer.expires_on&.strftime("%d.%m.%Y"),
          latitude: decimal(coordinates[:latitude]),
          longitude: decimal(coordinates[:longitude])
        }.merge(category_values(offer))
      end

      def category_values(offer)
        CsvImport::CATEGORY_COLUMNS.to_h do |column, kind|
          [column, offer.categories_of(kind).map(&:name).join("#{CsvImport::VALUE_SEPARATOR} ").presence]
        end
      end

      def visibility(offer)
        return I18n.t("adm.offers.offers.index.visibility.visible") if offer.published?

        { suspended: offer.suspended?, deactivated: offer.deactivated?, expired: offer.expired? }
          .select { |_, active| active }
          .map { |state, _| I18n.t("adm.offers.offers.index.visibility.#{state}") }
          .join(", ")
      end

      def guard_formula(value)
        value.is_a?(String) && value.match?(CsvImport::FORMULA_START) ? "'#{value}" : value
      end

      def decimal(value)
        value&.to_s&.tr(".", ",")
      end
  end
end
