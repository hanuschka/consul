class Adm::DeficiencyReports::IntakeChannelPolicy < ApplicationPolicy
  include Adm::DeficiencyReports::Concerns::DeficiencyReportManageable

  def index?
    deficiency_report_manager?
  end

  def new?
    deficiency_report_manager?
  end

  def create?
    deficiency_report_manager?
  end

  def edit?
    deficiency_report_manager?
  end

  def update?
    deficiency_report_manager?
  end

  def destroy?
    deficiency_report_manager?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
