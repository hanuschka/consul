module DeficiencyReports
  module ManagementReports
    class ScheduleDue < ApplicationService
      def initialize(now = Time.current)
        @now = now
      end

      def call
        DeficiencyReport::ReportProfile.active.find_each do |profile|
          next unless profile.due_at?(@now)
          next if profile.management_reports.scheduled.where(created_at: @now.beginning_of_hour..@now.end_of_hour).exists?

          DeficiencyReport::ManagementReport.start_for(profile, trigger: :scheduled, deliver: true, now: @now)
        end
      end
    end
  end
end
