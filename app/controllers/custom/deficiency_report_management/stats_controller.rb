class DeficiencyReportManagement::StatsController < DeficiencyReportManagement::BaseController
  def show
    @by_status = DeficiencyReport::Status.all.map do |status|
      [status, DeficiencyReport.where(status: status)]
    end

    @by_category = DeficiencyReport::Category.all.map do |category|
      [category, DeficiencyReport.where(category: category)]
    end

    @by_responsible = deficiency_report_all_responsible_sorted.map do |responsible|
      [responsible, DeficiencyReport.where(responsible: responsible)]
    end
  end
end
