class Adm::DeficiencyReports::DeficiencyReportAuditsController < Adm::DeficiencyReports::BaseController
  def show
    @deficiency_report = DeficiencyReport.find(params[:deficiency_report_id])
    authorize @deficiency_report, :show?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @audit = @deficiency_report.own_and_associated_audits.find(params[:id])
  end
end
