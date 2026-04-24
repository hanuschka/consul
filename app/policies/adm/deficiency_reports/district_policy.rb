class Adm::DeficiencyReports::DistrictPolicy < ApplicationPolicy
  include Adm::DeficiencyReports::Concerns::DeficiencyReportManageable
  def index?
    deficiency_report_manager?
  end

  def edit?
    deficiency_report_manager?
  end

  def update?
    deficiency_report_manager?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
