namespace :deficiency_reports do
  desc "Archive closed deficiency reports"
  task archive_closed: :environment do
    ApplicationLogger.new.info "Archiving closed deficiency reports"
    DeficiencyReport.archive_closed
  end
end
