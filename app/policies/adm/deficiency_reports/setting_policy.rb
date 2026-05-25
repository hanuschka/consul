class Adm::DeficiencyReports::SettingPolicy < ApplicationPolicy
  include Adm::DeficiencyReports::Concerns::DeficiencyReportManageable

  def show?
    deficiency_report_manager?
  end

  def edit?
    deficiency_report_manager?
  end

  def update?
    deficiency_report_manager?
  end
end
