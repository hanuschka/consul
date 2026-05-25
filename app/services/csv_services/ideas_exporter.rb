module CsvServices
  class IdeasExporter < CsvServices::BaseService
    require "csv"

    def initialize(ideas)
      @ideas = ideas
    end

    def call
      CSV.generate(headers: true, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers

        @ideas.each do |idea|
          csv << row(idea)
        end
      end
    end

    private

      def headers
        [
          "ID", "Sichtbarkeit seit", "Autor",
          "Titel", "Beschreibungstext",
          "Status", "Standort",
          "Kategorie",
          "Gebiet",
          "Sachbearbeiter*in",
          "Video URL", "Im Namen von",
          "Stimmen für Erfolg", "Zeitrahmen",
          "Erstellt am",
          "Offizielle Antwort"
        ]
      end

      def row(idea)
        [
          idea.id, idea.admin_accepted_at, sanitize_for_csv(idea.author&.username),
          sanitize_for_csv(idea.title), sanitize_for_csv(strip_tags(idea.description)),
          status_label(idea),
          idea.map_location&.approximated_address,
          idea.category&.name,
          idea.map_location&.district&.name,
          sanitize_for_csv(idea.officer&.name),
          sanitize_for_csv(idea.video_url), sanitize_for_csv(idea.on_behalf_of),
          idea.votes_needed_for_success, idea.timeframe,
          idea.created_at,
          strip_tags(idea.official_answer)
        ]
      end

      def status_label(idea)
        return "ausstehend" if idea.admin_accepted_at.blank?

        ends_at = idea.admin_accepted_at + idea.timeframe.to_i.days
        ends_at >= Time.zone.now.beginning_of_day ? "aktiv" : "archiviert"
      end
  end
end
