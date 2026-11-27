class DeficiencyReports::GenerateManagementReportJob < ApplicationJob
  queue_as :default
  self.max_run_time = Ai::Settings::JOB_MAX_RUN_TIME

  def perform(management_report_id)
    report = DeficiencyReport::ManagementReport.find(management_report_id)

    DeficiencyReports::ManagementReports::Generate.call(report)
    DeficiencyReports::ManagementReports::Deliver.call(report) if report.reload.deliverable?
  end
end
