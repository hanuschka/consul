class DeficiencyReportManagement::DeficiencyReportProgressBarsController < DeficiencyReportManagement::ProgressBarsController
  private

    def progressable
      DeficiencyReport.find(params[:deficiency_report_id])
    end
end
