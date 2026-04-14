class Adm::DeficiencyReports::BaseController < Adm::BaseController
  include DeficiencyReportsHelper

  before_action :authenticate_user!
  before_action :verify_deficiency_report_manager

  private

    def adm_header_title
      I18n.t("adm.deficiency_reports.title")
    end

    def adm_menu_component
      Adm::DeficiencyReports::MenuComponent.new
    end

    def verify_deficiency_report_manager
      raise Pundit::NotAuthorizedError unless current_user&.deficiency_report_manager? ||
                                              current_user&.deficiency_report_officer? ||
                                              current_user&.administrator?
    end

    def authenticate_user!
      redirect_to new_user_session_path unless current_user
    end

    def scoped_deficiency_reports
      base = policy_scope(DeficiencyReport, policy_scope_class: Adm::DeficiencyReports::DeficiencyReportPolicy::Scope)
      filter_assigned_reports_only(base)
    end

    def filter_assigned_reports_only(scope)
      return scope if current_user.administrator? || current_user.deficiency_report_manager?
      return scope unless Setting["deficiency_reports.admins_must_assign_officer"].present?
      return scope unless current_user.deficiency_report_officer?

      officer = current_user.deficiency_report_officer
      officer_group_ids = DeficiencyReport::OfficerGroup.joins(:officers).where(deficiency_report_officers: { id: officer.id }).pluck(:id)

      scope.where(
        "(responsible_type = ? AND responsible_id = ?) OR (responsible_type = ? AND responsible_id IN (?))",
        "DeficiencyReport::Officer", officer.id,
        "DeficiencyReport::OfficerGroup", officer_group_ids
      )
    end
end
