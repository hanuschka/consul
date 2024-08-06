module CsvServices
  class DeficiencyReportsExporter < ApplicationService
    require "csv"

    def initialize(deficiency_reports)
      @deficiency_reports = deficiency_reports
    end

    def call
      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << headers

        @deficiency_reports.each do |deficiency_report|
          csv << row(deficiency_report)
        end
      end
    end

    private

      def headers
        [
          "ID", "Sichtbarkeit", "Title", "Autor",
          "Status", "Standort", "Kategorie", "Sachbearbeiter*in",
          "Video URL", "Meldung im Namen von",
          "Erstellt am"
        ]
      end

      def row(dr)
        [
          dr.id, dr.admin_accepted, dr.title, dr.author.username,
          dr.status&.title, dr.map_location&.approximated_address, dr.category&.name, dr.admin_accepted,
          dr.video_url, dr.on_behalf_of,
          I18n.l(dr.created_at, format: "%d.%m.%Y")
        ]
      end
  end
end
