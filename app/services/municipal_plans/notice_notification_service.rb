module MunicipalPlans
  # A Hinweis goes to the people who maintain the Vorhaben: the Sachbearbeitung it is assigned to,
  # every member where that is a Bearbeitergruppe, and the Systempostfach on top where one is set.
  class NoticeNotificationService < ApplicationService
    def initialize(notice)
      @notice = notice
    end

    def call
      recipients.each do |email|
        MunicipalPlanMailer.notice_submitted(notice, email).deliver_later
      end
    end

    private

      attr_reader :notice

      def recipients
        (responsible_emails + [notice.municipal_plan.system_mailbox_email]).compact_blank.uniq
      end

      def responsible_emails
        case responsible
        when MunicipalPlan::Officer then [responsible.user&.email]
        when MunicipalPlan::OfficerGroup then responsible.officers.map { |o| o.user&.email }
        else []
        end
      end

      def responsible
        notice.municipal_plan.responsible
      end
  end
end
