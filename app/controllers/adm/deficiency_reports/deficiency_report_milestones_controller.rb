class Adm::DeficiencyReports::DeficiencyReportMilestonesController < Adm::DeficiencyReports::MilestonesController
  private

    def milestoneable
      DeficiencyReport.find(params[:deficiency_report_id])
    end
end
