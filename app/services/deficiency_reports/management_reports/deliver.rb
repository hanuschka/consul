module DeficiencyReports
  module ManagementReports
    class Deliver < ApplicationService
      def initialize(report)
        @report = report
      end

      def call
        profile = @report.report_profile
        users = profile.recipient_users.to_a
        user_emails = users.map { |user| user.email.to_s.downcase }

        users.each do |user|
          next if user.email.blank?

          DeficiencyReportMailer.management_report(@report, user.email, user).deliver_later
        end

        (profile.recipient_emails - user_emails).each do |email|
          DeficiencyReportMailer.management_report(@report, email).deliver_later
        end

        @report.update!(sent_at: Time.current)
      end
    end
  end
end
