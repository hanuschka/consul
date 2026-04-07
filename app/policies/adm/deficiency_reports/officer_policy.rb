class Adm::DeficiencyReports::OfficerPolicy < ApplicationPolicy
  def index?
    deficiency_report_manager?
  end

  def search?
    deficiency_report_manager?
  end

  def create?
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

  private

    def deficiency_report_manager?
      @user&.administrator? || @user&.deficiency_report_manager?
    end
end
