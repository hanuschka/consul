module CsvServices
  class ProjektEventRegistrationsExporter < CsvServices::BaseService
    require "csv"

    def initialize(registrations)
      @registrations = registrations
    end

    def call
      CSV.generate(headers: true, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers

        @registrations.each do |registration|
          csv << row(registration)
        end
      end
    end

    private

      def headers
        [
          I18n.t("custom.admin.projekt_phases.projekt_events.registration_user_id"),
          I18n.t("custom.admin.projekt_phases.projekt_events.registration_user"),
          I18n.t("custom.admin.projekt_phases.projekt_events.registration_email"),
          I18n.t("custom.admin.projekt_phases.projekt_events.registration_status"),
          I18n.t("custom.admin.projekt_phases.projekt_events.registration_date")
        ]
      end

      def row(registration)
        [
          registration.user_id,
          sanitize_for_csv(registration.display_name),
          sanitize_for_csv(registration.user&.email || registration.email),
          registration.status,
          I18n.l(registration.created_at, format: "%d.%m.%Y %H:%M")
        ]
      end
  end
end
