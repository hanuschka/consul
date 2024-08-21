module NotificationServices
  class DeficiencyReportOfficialAnswerUpdate < ApplicationService
    def initialize(deficiency_report_id)
      @deficiency_report = DeficiencyReport.find(deficiency_report_id)
    end

    def call
      users_to_notify.each do |user|
        DeficiencyReportMailer.notify_administrators_about_answer_update(@deficiency_report, user).deliver_later
        Notification.add(user, @deficiency_report)
        Activity.log(user, "email", @deficiency_report)
      end
    end

    private

      def users_to_notify
        [administrators, deficiency_report_managers]
          .flatten.uniq(&:id).reject { |user| user.id == @deficiency_report.author_id }
      end

      def administrators
        User.joins(:administrator).where(adm_email_on_new_deficiency_report: true).to_a
      end

      def deficiency_report_managers
        User.joins(:deficiency_report_manager).to_a
      end
  end
end
