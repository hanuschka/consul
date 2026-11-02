module DeficiencyReports
  module ManagementReports
    class Generate < ApplicationService
      def initialize(report)
        @report = report
      end

      def call
        @report.update!(status: :processing, error_message: nil)

        figures = Figures.call(@report.report_profile, @report.period, @report.building_blocks)
        sections = Summarize.call(@report, figures)

        @report.update!(status: :completed, figures: figures, sections: sections, generated_at: Time.current)
      rescue StandardError => e
        Rails.logger.error("[ManagementReport #{@report.id}] #{e.class}: #{e.message}")
        Sentry.capture_exception(e, level: :warning) if defined?(Sentry)
        @report.update!(status: :failed, error_message: "#{e.class}: #{e.message}".truncate(1000))
      end
    end
  end
end
