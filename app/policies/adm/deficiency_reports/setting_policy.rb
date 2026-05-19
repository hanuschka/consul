class Adm::DeficiencyReports::SettingPolicy < ApplicationPolicy
  include Adm::DeficiencyReports::Concerns::DeficiencyReportManageable

  def show?
    deficiency_report_manager?
  end
end
