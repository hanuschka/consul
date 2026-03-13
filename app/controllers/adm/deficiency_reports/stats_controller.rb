class Adm::DeficiencyReports::StatsController < Adm::DeficiencyReports::BaseController
  def show
    authorize :deficiency_report, :show?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @by_status = DeficiencyReport::Status.all.map do |status|
      [status, DeficiencyReport.where(status: status)]
    end

    @by_category = DeficiencyReport::Category.all.map do |category|
      [category, DeficiencyReport.where(category: category)]
    end

    @by_responsible = deficiency_report_all_responsible_sorted.map do |responsible|
      [responsible, DeficiencyReport.where(responsible: responsible)]
    end

    @all_deficiency_reports = DeficiencyReport.all

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.stats") }]
  end
end
