class Adm::DeficiencyReports::DistrictPolicy < ApplicationPolicy
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

  private

    def deficiency_report_manager?
      @user&.administrator? || @user&.deficiency_report_manager?
    end
end
