class Adm::DeficiencyReports::OfficialAnswerTemplatePolicy < ApplicationPolicy
  include Adm::DeficiencyReports::Concerns::DeficiencyReportManageable
  def index?
    manager_or_officer?
  end

  def new?
    manager_or_officer?
  end

  def create?
    manager_or_officer?
  end

  def edit?
    manager_or_officer?
  end

  def update?
    manager_or_officer?
  end

  def destroy?
    manager_or_officer?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

    def manager_or_officer?
      deficiency_report_manager? || @user&.deficiency_report_officer?
    end
end
