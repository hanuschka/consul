module DeficiencyReports
  class SubmissionNotificationService < ApplicationService
    def initialize(deficiency_report)
      @deficiency_report = deficiency_report
    end

    def call
      NotificationServices::NewDeficiencyReportNotifier.new(@deficiency_report.id).call
      notify_responsible

      return unless @deficiency_report.reporter_mailable?

      DeficiencyReportMailer.notify_author_about_submission(@deficiency_report).deliver_later
    end

    private

      def notify_responsible
        responsible = @deficiency_report.responsible

        if responsible.is_a?(DeficiencyReport::OfficerGroup) && responsible.default_email.present?
          DeficiencyReportMailer.notify_default_officer_group_email(@deficiency_report).deliver_later
        end

        @deficiency_report.responsible_officers.each do |officer|
          if @deficiency_report.email_officers_individually?
            DeficiencyReportMailer.notify_officer(@deficiency_report, officer).deliver_later
            Activity.log(officer.user, "email", @deficiency_report)
          end

          Notification.add(officer.user, @deficiency_report)
        end
      end
  end
end
