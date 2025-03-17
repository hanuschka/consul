module NotificationServices
  class OverdueDeficiencyReportsReminder < ApplicationService
    def initialize
      @threshold_date = 14.days.ago
    end

    def call
      officers_with_overdue_reports_ids.each do |officer_id|
        NotificationServiceMailer.overdue_deficiency_reports(officer_id, overdue_reports_ids_for_officer(officer_id)).deliver_later
      end
    end

    private

      def overdue_reports
        DeficiencyReport.where(official_answer: [nil, ""])
                        .where(assigned_at: @threshold_date.midnight..@threshold_date.end_of_day)
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
