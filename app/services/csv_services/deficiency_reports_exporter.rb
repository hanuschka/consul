module CsvServices
  class DeficiencyReportsExporter < ApplicationService
    require "csv"
    include JsonExporter

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
          dr.id, dr.admin_accepted, dr.author.username,
          dr.title, strip_tags(dr.description),
          dr.status&.title, dr.map_location&.approximated_address, dr.area&.name,
          dr.category&.name,
          dr.officer&.user&.username, dr.assigned_at,
          dr.video_url, dr.on_behalf_of,
          dr.created_at,
          strip_tags(dr.official_answer)
        ]
      end
  end
end
