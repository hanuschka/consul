module Adm::DeficiencyReports::Concerns::DeficiencyReportManageable
  extend ActiveSupport::Concern

  private

    def deficiency_report_manager?
      @user&.administrator? || @user&.deficiency_report_manager? || officer_with_manage_all?
    end

    def officer_with_manage_all?
      @user&.deficiency_report_officer? && @user.deficiency_report_officer.manage_all?
    end
end
