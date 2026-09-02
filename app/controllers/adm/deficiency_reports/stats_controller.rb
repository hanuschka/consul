class Adm::DeficiencyReports::StatsController < Adm::DeficiencyReports::BaseController
  def show
    authorize :deficiency_report, :stats?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    all = DeficiencyReport.all
    @all_deficiency_reports = all

    # ── KPI cards ──
    @total = all.count
    @open = all.where(deficiency_report_status_id: DeficiencyReport::Status.default&.id).count
    @open_pct = @total.positive? ? ((@open.to_f / @total) * 100).round(0) : nil
    @unassigned = all.where(responsible_id: nil).count

    now = Time.zone.now
    @new_this_week = all.where(created_at: now.beginning_of_week..now.end_of_week).count
    @new_last_week = all.where(created_at: now.prev_week.beginning_of_week..now.prev_week.end_of_week).count
    @trend_week = compute_trend(@new_this_week, @new_last_week)

    @new_this_month = all.where(created_at: now.beginning_of_month..now.end_of_month).count
    @new_last_month = all.where(created_at: now.prev_month.beginning_of_month..now.prev_month.end_of_month).count
    @trend_month = compute_trend(@new_this_month, @new_last_month)

    # ── Satisfaction KPIs ──
    feedback_scope = all.joins(:feedback_form)
    @feedback_count = feedback_scope.count
    if @feedback_count.positive?
      @satisfaction_avg = feedback_scope.average("deficiency_report_feedback_forms.overall_satisfaction")&.round(1)
      @response_time_avg = feedback_scope.average("deficiency_report_feedback_forms.response_time_satisfaction")&.round(1)
      @communication_avg = feedback_scope.average("deficiency_report_feedback_forms.communication_satisfaction")&.round(1)
    end

    # ── Chart: reports per month (last 12 months) ──
    @chart_reports = build_monthly_chart(all)

    # ── Chart: by status ──
    @status_chart_labels = []
    @status_chart_values = []
    DeficiencyReport::Status.all.each do |status|
      count = all.where(status: status).count
      next if count.zero?
      @status_chart_labels << status.name
      @status_chart_values << count
    end

    # ── Chart: by category (top 10) ──
    @category_chart_labels = []
    @category_chart_values = []
    DeficiencyReport::Category.left_joins(:deficiency_reports)
      .group(:id)
      .order("COUNT(deficiency_reports.id) DESC")
      .limit(10)
      .count("deficiency_reports.id")
      .each do |category_id, count|
        next if count.zero?
        cat = DeficiencyReport::Category.find(category_id)
        @category_chart_labels << cat.name
        @category_chart_values << count
      end

    # ── Chart: by intake channel ──
    @intake_channel_chart_labels = []
    @intake_channel_chart_values = []
    DeficiencyReport::IntakeChannel.all.each do |channel|
      count = all.where(intake_channel: channel).count
      next if count.zero?

      @intake_channel_chart_labels << channel.name
      @intake_channel_chart_values << count
    end

    # ── Detail tables ──
    @by_status = DeficiencyReport::Status.all.map do |status|
      [status, DeficiencyReport.where(status: status)]
    end

    @by_category = DeficiencyReport::Category.all.map do |category|
      [category, DeficiencyReport.where(category: category)]
    end

    @by_responsible = deficiency_report_all_responsible_sorted.map do |responsible|
      [responsible, DeficiencyReport.where(responsible: responsible)]
    end

    @by_intake_channel = DeficiencyReport::IntakeChannel.all.map do |channel|
      [channel, DeficiencyReport.where(intake_channel: channel)]
    end

    # Reports a dimension does not cover were missing from its table while still counting towards the
    # total row underneath, so the rows never added up. Appended only when the group has members.
    { @by_category => :deficiency_report_category_id,
      @by_responsible => :responsible_id,
      @by_intake_channel => :deficiency_report_intake_channel_id }.each do |groups, column|
      uncovered = all.where(column => nil)
      groups << [nil, uncovered] if uncovered.exists?
    end

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.stats"), icon: "bar_chart" }]
  end

  private

    def compute_trend(current, previous)
      delta = current - previous
      pct = previous.positive? ? ((delta.to_f / previous) * 100).round(0) : nil
      { delta: delta, pct: pct }
    end

    def build_monthly_chart(scope)
      labels = []
      values = []
      12.times do |i|
        date = i.months.ago
        month_start = date.beginning_of_month
        month_end = date.end_of_month
        labels.unshift(I18n.l(month_start, format: "%b %y"))
        values.unshift(scope.where(created_at: month_start..month_end).count)
      end
      { labels: labels, values: values }
    end
end
