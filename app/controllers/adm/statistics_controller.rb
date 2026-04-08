module Adm
  class StatisticsController < Adm::BaseController
    def show
      authorize [:adm, :statistics]
      @breadcrumbs = [{ name: t("adm.statistics.show.title"), icon: "bar_chart_4_bars" }]

      load_user_stats
      load_projekt_stats
      load_phase_stats
      load_deficiency_report_stats
      load_demographics
      load_charts
    end

    private

      def load_user_stats
        @users_total        = User.active.count
        @users_new_week     = User.active.where("users.created_at >= ?", 7.days.ago).count
        @users_new_month    = User.active.where("users.created_at >= ?", 1.month.ago).count
        @users_verified_l1  = User.active.where.not(verified_at: nil).count
        @users_verified_l2  = User.active.where.not(level_two_verified_at: nil).count
        @users_deleted      = User.where.not(erased_at: nil).count
        @users_guest        = User.active.where(guest: true).count

        prev_week  = User.active.where("users.created_at >= ? AND users.created_at < ?", 14.days.ago, 7.days.ago).count
        prev_month = User.active.where("users.created_at >= ? AND users.created_at < ?", 2.months.ago, 1.month.ago).count
        @trend_users_week  = trend_delta(@users_new_week, prev_week)
        @trend_users_month = trend_delta(@users_new_month, prev_month)

        @users_newsletter      = User.active.newsletter.count

        @users_verified_l1_pct  = ratio_pct(@users_verified_l1, @users_total)
        @users_verified_l2_pct  = ratio_pct(@users_verified_l2, @users_total)
        @users_newsletter_pct   = ratio_pct(@users_newsletter, @users_total)
      end

      def load_projekt_stats
        @projects_total         = Projekt.regular.count
        @projects_current       = Projekt.current.regular.count
        @projects_expired       = Projekt.expired.regular.count
        @projects_subscriptions = ProjektSubscription.where(active: true).count
        @projects_active_pct    = ratio_pct(@projects_current, @projects_total)
      end

      def load_phase_stats
        @phase_counts                  = ProjektPhase.unscoped.group(:type).count
        @stat_comments                 = Comment.where(hidden_at: nil).count
        @stat_proposals                = Proposal.not_archived.not_retired.where(draft: false).where.not(published_at: nil).count
        @stat_proposal_comments        = Comment.where(hidden_at: nil, commentable_type: "Proposal").count
        @stat_question_answers         = ProjektQuestionAnswer.count
        @stat_poll_answers             = Poll::Answer.count
        @stat_budget_investments       = Budget::Investment.count
        @stat_budget_comments          = Comment.where(hidden_at: nil, commentable_type: "Budget::Investment").count
        @stat_formular_answers         = FormularAnswer.count
        @stat_legislation_annotations  = Legislation::Annotation.count
        @stat_projekt_arguments        = ProjektArgument.count
        @stat_points_of_interest       = ProjektPointOfInterestPin.count
        @stat_projekt_events           = ProjektEvent.count
        @stat_milestones               = Milestone.count
        @stat_livestreams              = ProjektLivestream.count
      end

      def load_deficiency_report_stats
        @reports_total      = DeficiencyReport.not_archived.count
        @reports_open       = DeficiencyReport.not_closed.not_archived.count
        @reports_unassigned = DeficiencyReport.not_assigned.not_archived.count
        @reports_open_pct   = ratio_pct(@reports_open, @reports_total)
      end

      def load_demographics
        @gender_stats  = User.active.where.not(gender: nil).group(:gender).count
        @geozone_stats = User.active
                             .where.not(geozone_id: nil)
                             .joins(:geozone)
                             .group("geozones.name")
                             .order(Arel.sql("COUNT(*) DESC"))
                             .limit(10)
                             .count
      end

      def load_charts
        @chart_users     = monthly_chart_data(User.active, "users.created_at")
        @chart_comments  = monthly_chart_data(Comment.where(hidden_at: nil), "comments.created_at")
        @chart_proposals = monthly_chart_data(
          Proposal.not_archived.not_retired.where(draft: false).where.not(published_at: nil),
          "proposals.published_at"
        )
      end

      def trend_delta(current, previous)
        return nil if current.zero? && previous.zero?
        delta = current - previous
        pct   = previous.zero? ? nil : (delta.to_f / previous * 100).round
        { delta: delta, pct: pct }
      end

      def ratio_pct(part, total)
        return nil if total.nil? || total.zero?
        (part.to_f / total * 100).round
      end

      def monthly_chart_data(scope, column)
        start_date = 11.months.ago.beginning_of_month.utc
        months     = (0..11).map { |i| (start_date + i.months).beginning_of_month }

        raw = scope
          .where("#{column} >= ?", start_date)
          .group(Arel.sql("DATE_TRUNC('month', #{column})"))
          .count

        raw_by_date = raw.transform_keys(&:to_date)

        {
          labels: months.map { |m| m.to_date.strftime("%b %Y") },
          values: months.map { |m| raw_by_date[m.to_date] || 0 }
        }
      end
  end
end
