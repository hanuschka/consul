namespace :deficiency_reports do
  desc "Archive closed deficiency reports"
  task archive_closed: :environment do
    ApplicationLogger.new.info "Archiving closed deficiency reports"
    DeficiencyReport.archive_closed
  end

  desc "Create and send the management reports that are due this hour"
  task management_reports: :environment do
    ApplicationLogger.new.info "Creating due deficiency report management reports"
    DeficiencyReports::ManagementReports::ScheduleDue.call
  end
end
