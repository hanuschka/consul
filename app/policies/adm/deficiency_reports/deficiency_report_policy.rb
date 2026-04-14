class Adm::DeficiencyReports::DeficiencyReportPolicy < ApplicationPolicy
  def index?
    deficiency_report_manager_or_officer?
  end

  def show?
    deficiency_report_manager_or_officer?
  end

  def edit?
    deficiency_report_manager_or_officer?
  end

  def update?
    deficiency_report_manager_or_officer?
  end

  def destroy?
    deficiency_report_manager?
  end

  def audits?
    deficiency_report_manager_or_officer?
  end

  def accept?
    deficiency_report_manager?
  end

  def toggle_image?
    deficiency_report_manager?
  end

  def settings?
    deficiency_report_manager?
  end

  def feedback_form?
    deficiency_report_manager_or_officer?
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

    def deficiency_report_manager_or_officer?
      deficiency_report_manager? || @user&.deficiency_report_officer?
    end
end
