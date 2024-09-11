module NotificationServices
  class NewDeficiencyReportNotifier < ApplicationService
    def initialize(deficiency_report_id)
      @deficiency_report = DeficiencyReport.find(deficiency_report_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_deficiency_report(user.id, @deficiency_report.id).deliver_later
        Notification.add(user, @deficiency_report)
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
  end
end
