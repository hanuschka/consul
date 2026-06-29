class Adm::DeficiencyReports::DeficiencyReportPolicy < ApplicationPolicy
  include Adm::DeficiencyReports::Concerns::DeficiencyReportManageable
  def index?
    deficiency_report_manager_or_officer?
  end

  def new?
    deficiency_report_manager?
  end

  def create?
    deficiency_report_manager?
  end

  def show?
    deficiency_report_manager? || assigned_officer?
  end

  def edit?
    deficiency_report_manager? || assigned_officer?
  end

  def update?
    deficiency_report_manager? || assigned_officer?
  end

  def destroy?
    deficiency_report_manager?
  end

  def audits?
    deficiency_report_manager? || assigned_officer?
  end

  def accept?
    deficiency_report_manager?
  end

  def toggle_image?
    deficiency_report_manager?
  end

  def stats?
    deficiency_report_manager?
  end

  def settings?
    deficiency_report_manager?
  end

  def feedback_form?
    deficiency_report_manager? || assigned_officer?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

    def deficiency_report_manager_or_officer?
      deficiency_report_manager? || @user&.deficiency_report_officer?
    end

    def assigned_officer?
      return false unless @user&.deficiency_report_officer?
      return false unless @record.is_a?(DeficiencyReport)
      return true unless Setting["deficiency_reports.admins_must_assign_officer"].present?

      officer = @user.deficiency_report_officer
      return true if officer.manage_all?
      return true if @record.responsible == officer

      if @record.responsible.is_a?(DeficiencyReport::OfficerGroup)
        @record.responsible.officers.exists?(id: officer.id)
      else
        false
      end
    end
end
