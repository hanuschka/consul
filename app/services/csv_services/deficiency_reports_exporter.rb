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
          "Status", "Standort", "Area",
          "Kategorie",
          "Sachbearbeiter*in", "Zugewiesen an",
          "Video URL", "Meldung im Namen von",
          "Erstellt am",
          "Officielle Antwort genehmigt", "Officielle Antwort"
        ]
      end

      def row(dr)
        [
          dr.id, dr.admin_accepted, dr.title, dr.author.username,
          dr.status&.title, dr.map_location&.approximated_address, dr.area&.name,
          dr.category&.name,
          dr.officer&.user&.username, dr.assigned_at,
          dr.video_url, dr.on_behalf_of,
          dr.created_at,
          dr.official_answer_approved, dr.official_answer
        ]
      end
  end
end
