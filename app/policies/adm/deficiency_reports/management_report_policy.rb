class Adm::DeficiencyReports::ManagementReportPolicy < ApplicationPolicy
  include Adm::DeficiencyReports::Concerns::DeficiencyReportManageable

  def show?
    deficiency_report_manager? || recipient?
  end

  def retry?
    deficiency_report_manager? && @record.failed?
  end

  private

    def recipient?
      @user.present? && @record.report_profile.recipient_user_ids.include?(@user.id)
    end
end
