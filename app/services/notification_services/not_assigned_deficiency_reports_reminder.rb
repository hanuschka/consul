module NotificationServices
  class NotAssignedDeficiencyReportsReminder < ApplicationService
    def initialize
      @threshold_date = 14.days.ago
    end

    def call
      return if reports_with_overdue_assignment_ids.blank?

      users_to_notify.each do |user|
        NotificationServiceMailer.not_assigned_deficiency_reports(user.id, reports_with_overdue_assignment_ids).deliver_later
        Activity.log(user, "email", @deficiency_report)
      end
    end

    private

      def users_to_notify
        [administrators, deficiency_report_administrators]
          .flatten.uniq(&:id)
      end

      def administrators
        User.joins(:administrator).where(adm_email_on_new_deficiency_report: true).to_a
      end

      def deficiency_report_administrators
        User.joins(:deficiency_report_manager).to_a
      end

      def reports_with_overdue_assignment_ids
        DeficiencyReport.where(deficiency_report_officer_id: nil)
          .where(assigned_at: @threshold_date.midnight..@threshold_date.end_of_day)
          .ids
      end
  end
end
