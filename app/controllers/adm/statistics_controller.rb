module Adm
  class StatisticsController < Adm::BaseController
    def show
      authorize [:adm, :statistics]
      @breadcrumbs = [
        { name: t("adm.menu.items.stats"), icon: "bar_chart_4_bars" },
        { name: t("adm.menu.items.stats_subitems.overview") }
      ]

      load_user_stats
      load_projekt_stats
      load_phase_stats
      load_deficiency_report_stats
      load_demographics
      load_charts
    end

    private

      def load_user_stats
        # "aktiv" = nicht gelöscht, kein Gast, bestätigter Account (User.actual).
        # Gäste und gelöschte Nutzer werden separat gezählt.
        @users_total        = User.actual.count
        @users_new_week     = User.actual.where("users.created_at >= ?", 7.days.ago).count
        @users_new_month    = User.actual.where("users.created_at >= ?", 1.month.ago).count
        @users_verified_l1  = User.actual.where.not(verified_at: nil).count
        @users_verified_l2  = User.actual.where.not(level_two_verified_at: nil).count
        @users_deleted      = User.where.not(erased_at: nil).count
        @users_guest        = User.active.where(guest: true).count

        prev_week  = User.actual.where("users.created_at >= ? AND users.created_at < ?", 14.days.ago, 7.days.ago).count
        prev_month = User.actual.where("users.created_at >= ? AND users.created_at < ?", 2.months.ago, 1.month.ago).count
        @trend_users_week  = trend_delta(@users_new_week, prev_week)
        @trend_users_month = trend_delta(@users_new_month, prev_month)

        @users_newsletter      = User.actual.newsletter.count

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
        @gender_stats  = User.actual.where.not(gender: nil).group(:gender).count
        @geozone_stats = User.actual
                             .where.not(geozone_id: nil)
                             .joins(:geozone)
                             .group("geozones.name")
                             .order(Arel.sql("COUNT(*) DESC"))
                             .limit(10)
                             .count
      end

      def load_charts
        @chart_users = {
          daily: chart_data(User.actual, "users.created_at", :day),
          weekly: chart_data(User.actual, "users.created_at", :week),
          monthly: chart_data(User.actual, "users.created_at", :month),
          yearly: chart_data(User.actual, "users.created_at", :year)
        }
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
        chart_data(scope, column, :month)
      end

      def chart_data(scope, column, unit)
        today = Time.current.utc.to_date

        case unit
        when :day
          periods = ((today - 29)..today).to_a
          label   = ->(date) { date.strftime("%d.%m.") }
        when :week
          # DATE_TRUNC('week') is always ISO/Monday, regardless of Date.beginning_of_week
          periods = (0..25).map { |i| (today - (25 - i).weeks).beginning_of_week(:monday) }
          label   = ->(date) { date.strftime("%d.%m.") }
        when :month
          periods = (0..11).map { |i| (today << (11 - i)).beginning_of_month }
          label   = ->(date) { date.strftime("%b %Y") }
        when :year
          first_year = [scope.minimum(column)&.year || today.year, today.year - 9].max
          periods    = (first_year..today.year).map { |year| Date.new(year) }
          label      = ->(date) { date.strftime("%Y") }
        end

        raw = scope
          .where("#{column} >= ?", periods.first)
          .group(Arel.sql("DATE_TRUNC('#{unit}', #{column})"))
          .count

        raw_by_date = raw.transform_keys(&:to_date)

        {
          labels: periods.map(&label),
          values: periods.map { |period| raw_by_date[period] || 0 }
        }
      end
  end
end
