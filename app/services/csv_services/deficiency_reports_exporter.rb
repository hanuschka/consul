module CsvServices
  class DeficiencyReportsExporter < CsvServices::BaseService
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
          "ID", "Sichtbarkeit", "Autor",
          "Titel", "Beschreibungstext",
          "Status", "Standort", "Area",
          "Kategorie",
          "Sachbearbeiter*in", "Zugewiesen an",
          "Video URL", "Meldung im Namen von",
          "Erstellt am",
          "Officielle Antwort"
        ]
      end

      def row(dr)
        [
          dr.id, dr.admin_accepted, sanitize_for_csv(dr.author.username),
          sanitize_for_csv(dr.title), sanitize_for_csv(strip_tags(dr.description)),
          dr.status&.title, dr.map_location&.approximated_address, dr.area&.name,
          dr.category&.name,
          sanitize_for_csv(dr.responsible&.name), dr.assigned_at,
          sanitize_for_csv(dr.video_url), sanitize_for_csv(dr.on_behalf_of),
          dr.created_at,
          strip_tags(dr.official_answer)
        ]
      end
  end
end
