class Adm::DeficiencyReports::ManagementReportsController < Adm::DeficiencyReports::BaseController
  def show
    @management_report = DeficiencyReport::ManagementReport.find(params[:id])
    authorize @management_report, policy_class: Adm::DeficiencyReports::ManagementReportPolicy

    respond_to do |format|
      format.html do
        @breadcrumbs = breadcrumbs
      end
      format.pdf do
        pdf = PdfServices::DeficiencyReportManagementReportExporter.call(@management_report, request.host)
        send_data pdf.render, filename: "bericht_#{@management_report.id}.pdf", type: "application/pdf"
      end
    end
  end

  def retry
    @management_report = DeficiencyReport::ManagementReport.find(params[:id])
    authorize @management_report, policy_class: Adm::DeficiencyReports::ManagementReportPolicy

    @management_report.retry!
    redirect_to adm_deficiency_reports_report_profile_path(@management_report.report_profile), notice: t(".success")
  end

  private

    def breadcrumbs
      title = { name: I18n.l(@management_report.period_end.to_date) }
      return [title] unless Adm::DeficiencyReports::ReportProfilePolicy.new(current_user, @management_report.report_profile).show?

      [
        { name: t("adm.deficiency_reports.report_profiles.index.title"), url: adm_deficiency_reports_report_profiles_path, icon: "summarize" },
        { name: @management_report.profile_name, url: adm_deficiency_reports_report_profile_path(@management_report.report_profile) },
        title
      ]
    end
end
