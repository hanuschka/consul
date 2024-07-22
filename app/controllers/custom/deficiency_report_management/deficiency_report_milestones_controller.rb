class DeficiencyReportManagement::DeficiencyReportMilestonesController < DeficiencyReportManagement::MilestonesController
  private

    def milestoneable
      DeficiencyReport.find(params[:deficiency_report_id])
    end
end
