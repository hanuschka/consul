module NotificationServices
  class OverdueDeficiencyReportsReminder < ApplicationService
    def call
      # The personal nudge is a one-day event: it only fires for officers whose Anliegen cross their
      # reminder delay today, so it goes quiet by itself on days without arrivals.
      officers_needing_personal_digest_ids.each do |officer_id|
        NotificationServiceMailer.overdue_deficiency_reports(officer_id, overdue_reports_ids_for_officer(officer_id)).deliver_later
      end

      # The oversight overview is a standing backlog report instead: it goes out every day for as
      # long as anything is still overdue, and stays silent only once the backlog is empty.
      return if still_overdue_report_ids.blank?

      oversight_officer_ids.each do |officer_id|
        NotificationServiceMailer.overdue_deficiency_reports_overview(
          officer_id, still_overdue_report_ids, fresh_report_ids
        ).deliver_later
      end
    end

    private

      # The Anliegen that cross their reminder delay today. This is what nudges the responsible
      # officer, and what marks a row as new in the oversight overview.
      def overdue_reports
        DeficiencyReport.overdue_candidates.where(Arel.sql("#{DeficiencyReport::OVERDUE_EFFECTIVE_DATE_SQL} = #{DeficiencyReport::OVERDUE_THRESHOLD_SQL}"))
      end

      # Everything still sitting past its reminder delay. The oversight overview is a standing
      # backlog rather than a one-day snapshot, so an Anliegen stays visible until it moves — and a
      # missed cron run no longer drops it silently.
      def still_overdue_reports
        DeficiencyReport.overdue
      end

      def officers_with_overdue_reports_ids
        overdue_reports.map(&:responsible_officers).flatten.pluck(:id).uniq
      end

      # An officer with manage_all is the module's admin in /adm, so they are told about every
      # overdue Anliegen rather than only the ones they are responsible for. That overview is a
      # superset of their personal digest, which is why they are dropped from it: one Anliegen must
      # not reach the same person in two separate mails.
      def officers_needing_personal_digest_ids
        officers_with_overdue_reports_ids - oversight_officer_ids
      end

      def oversight_officer_ids
        @oversight_officer_ids ||= DeficiencyReport::Officer.where(manage_all: true).ids
      end

      def fresh_report_ids
        @fresh_report_ids ||= overdue_reports.ids
      end

      def still_overdue_report_ids
        @still_overdue_report_ids ||= still_overdue_reports.ids
      end

      def overdue_reports_ids_for_officer(officer_id)
        officer = DeficiencyReport::Officer.find(officer_id)
        overdue_reports.where(responsible: officer)
          .or(overdue_reports.where(responsible: officer.officer_groups))
          .ids
      end
  end
end
