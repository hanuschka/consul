module NotificationServices
  class OverdueDeficiencyReportsReminder < ApplicationService
    def call
      officers_with_overdue_reports_ids.each do |officer_id|
        NotificationServiceMailer.overdue_deficiency_reports(officer_id, overdue_reports_ids_for_officer(officer_id)).deliver_later
      end
    end

    private

      def overdue_reports
        DeficiencyReport.assigned.not_closed
          .where.not(status_changed_at: nil)
          .where.not(deficiency_report_statuses: { reminder_delay: nil })
          .where(official_answer: [nil, ""])
          .where(
            Arel.sql("
              (
                CASE
                  WHEN abs(EXTRACT(EPOCH FROM (deficiency_reports.assigned_at - CURRENT_TIMESTAMP))) <
                       abs(EXTRACT(EPOCH FROM (deficiency_reports.status_changed_at - CURRENT_TIMESTAMP))) THEN deficiency_reports.assigned_at
                  ELSE deficiency_reports.status_changed_at
                END
              )::date = CURRENT_DATE - (deficiency_report_statuses.reminder_delay || ' days')::interval
            ")
          )
      end

      def officers_with_overdue_reports_ids
        overdue_reports.map(&:responsible_officers).flatten.pluck(:id).uniq
      end

      def overdue_reports_ids_for_officer(officer_id)
        officer = DeficiencyReport::Officer.find(officer_id)
        overdue_reports.where(responsible: officer)
          .or(overdue_reports.where(responsible: officer.officer_groups))
          .ids
      end
  end
end
