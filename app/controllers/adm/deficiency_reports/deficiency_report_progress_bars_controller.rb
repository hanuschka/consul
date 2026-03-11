class Adm::DeficiencyReports::DeficiencyReportProgressBarsController < Adm::DeficiencyReports::ProgressBarsController
  private

    def progressable
      DeficiencyReport.find(params[:deficiency_report_id])
    end
end
