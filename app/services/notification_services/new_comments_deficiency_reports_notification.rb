# frozen_string_literal: true

module NotificationServices
  class NewCommentsDeficiencyReportsNotification < ApplicationService
    def self.deliver(deficiency_report, last_notified_time, initial: false)
      if deficiency_report.responsible.is_a?(DeficiencyReport::OfficerGroup)
        NotificationServiceMailer
          .with(initial: initial)
          .new_comments_for_deficiency_report(deficiency_report, last_notified_time)
          .deliver_now
      end

      return unless deficiency_report.email_officers_individually?

      deficiency_report.responsible_officers.each do |officer|
        NotificationServiceMailer
          .with(officer: officer, initial: initial)
          .new_comments_for_deficiency_report(deficiency_report, last_notified_time)
          .deliver_now
      end
    end

    def initialize
      @threshold_date = 14.days.ago
    end

    def call
      DeficiencyReport.where(notify_officer_about_new_comments: true).find_each do |deficiency_report|
        next if deficiency_report.notified_officer_about_new_comments_datetime.to_date < 6.days.ago

        send_new_comments_email(deficiency_report)
      end
    end

    private

      def send_new_comments_email(deficiency_report)
        new_comments = deficiency_report.comments.created_after_date(
          deficiency_report.notified_officer_about_new_comments_datetime
        )

        last_notified_time = deficiency_report.notified_officer_about_new_comments_datetime

        deficiency_report.update!(notified_officer_about_new_comments_datetime: Time.current)

        self.class.deliver(deficiency_report, last_notified_time) if new_comments.exists?
      end
  end
end
