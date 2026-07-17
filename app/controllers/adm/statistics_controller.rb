module Adm
  class StatisticsController < Adm::BaseController
    MAX_CHART_RANGE_YEARS = 10

    def show
      authorize [:adm, :statistics]
      @chart_users_range = users_chart_range
      load_users_chart

      respond_to do |format|
        format.html do
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
        format.json do
          render json: {
            datasets: @chart_users,
            range: {
              start_date: @chart_users_range&.first&.iso8601,
              end_date: @chart_users_range&.last&.iso8601
            }
          }
        end
      end
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

      def load_users_chart
        @chart_users = {
          daily: chart_data(User.actual, "users.created_at", :day, range: @chart_users_range),
          weekly: chart_data(User.actual, "users.created_at", :week, range: @chart_users_range),
          monthly: chart_data(User.actual, "users.created_at", :month, range: @chart_users_range),
          yearly: chart_data(User.actual, "users.created_at", :year, range: @chart_users_range)
        }
      end

      def load_charts
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

      def users_chart_range
        from = parse_chart_date(params[:start_date])
        to   = parse_chart_date(params[:end_date])
        return nil unless from || to

        today = Time.current.utc.to_date
        to ||= today
        if from.nil?
          earliest = User.actual.minimum(:created_at)&.to_date || to
          from = [earliest, to].min
        end
        from, to = to, from if from > to
        to   = today if to > today
        from = today if from > today
        from = [from, to - MAX_CHART_RANGE_YEARS.years].max
        from..to
      end

      def parse_chart_date(value)
        return if value.blank?

        Date.iso8601(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def chart_data(scope, column, unit, range: nil)
        today = Time.current.utc.to_date
        day_format = range && range.first.year != range.last.year ? "%d.%m.%Y" : "%d.%m."

        case unit
        when :day
          periods = range ? range.to_a : ((today - 29)..today).to_a
          label   = ->(date) { date.strftime(day_format) }
        when :week
          # DATE_TRUNC('week') is always ISO/Monday, regardless of Date.beginning_of_week
          periods = if range
                      (range.first.beginning_of_week(:monday)..range.last).step(7).to_a
                    else
                      (0..25).map { |i| (today - (25 - i).weeks).beginning_of_week(:monday) }
                    end
          label   = ->(date) { date.strftime(day_format) }
        when :month
          periods = if range
                      first = range.first.beginning_of_month
                      count = (range.last.year * 12 + range.last.month) - (first.year * 12 + first.month)
                      (0..count).map { |i| first >> i }
                    else
                      (0..11).map { |i| (today << (11 - i)).beginning_of_month }
                    end
          label   = ->(date) { date.strftime("%b %Y") }
        when :year
          periods = if range
                      (range.first.year..range.last.year).map { |year| Date.new(year) }
                    else
                      first_year = [scope.minimum(column)&.year || today.year, today.year - 9].max
                      (first_year..today.year).map { |year| Date.new(year) }
                    end
          label   = ->(date) { date.strftime("%Y") }
        end

        # In range mode both bounds use the raw range (not truncated periods),
        # so totals are identical across granularities; first/last buckets may be partial.
        scoped = scope.where("#{column} >= ?", range ? range.first : periods.first)
        scoped = scoped.where("#{column} < ?", range.last + 1) if range

        raw = scoped
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
