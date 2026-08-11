module NotificationServices
  class OverdueDeficiencyReportsReminder < ApplicationService
    # Whichever of the two timestamps sits closer to now is the one the reminder delay counts from.
    EFFECTIVE_DATE_SQL = <<~SQL.squish.freeze
      (
        CASE
          WHEN abs(EXTRACT(EPOCH FROM (deficiency_reports.assigned_at - CURRENT_TIMESTAMP))) <
               abs(EXTRACT(EPOCH FROM (deficiency_reports.status_changed_at - CURRENT_TIMESTAMP))) THEN deficiency_reports.assigned_at
          ELSE deficiency_reports.status_changed_at
        END
      )::date
    SQL

    THRESHOLD_SQL = "CURRENT_DATE - (deficiency_report_statuses.reminder_delay || ' days')::interval".freeze

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

      def candidate_reports
        DeficiencyReport.assigned.not_closed
          .where.not(status_changed_at: nil)
          .where.not(deficiency_report_statuses: { reminder_delay: nil })
          .where(official_answer: [nil, ""])
      end

      # The Anliegen that cross their reminder delay today. This is what nudges the responsible
      # officer, and what marks a row as new in the oversight overview.
      def overdue_reports
        candidate_reports.where(Arel.sql("#{EFFECTIVE_DATE_SQL} = #{THRESHOLD_SQL}"))
      end

      # Everything still sitting past its reminder delay. The oversight overview is a standing
      # backlog rather than a one-day snapshot, so an Anliegen stays visible until it moves — and a
      # missed cron run no longer drops it silently.
      def still_overdue_reports
        candidate_reports.where(Arel.sql("#{EFFECTIVE_DATE_SQL} <= #{THRESHOLD_SQL}"))
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
