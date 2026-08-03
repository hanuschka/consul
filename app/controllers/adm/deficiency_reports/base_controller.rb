class Adm::DeficiencyReports::BaseController < Adm::BaseController
  include DeficiencyReportsHelper
  include OnBehalfOfAccountLinking

  before_action :authenticate_user!
  before_action :verify_deficiency_report_manager

  rescue_from Pundit::NotAuthorizedError do |exception|
    Sentry.capture_exception(exception, level: :warning)
    redirect_to adm_deficiency_reports_root_path, alert: t("adm.not_authorized")
  end

  private

    def verify_deficiency_report_manager
      raise Pundit::NotAuthorizedError unless current_user&.deficiency_report_manager? ||
                                              current_user&.deficiency_report_officer? ||
                                              current_user&.administrator?
    end

    # Filing a report for somebody else is part of the officer backend's job, and reaching a create
    # action here already means the policy admitted the user for it — including officers who manage
    # all reports, whom the public rule does not cover. So the namespace answers yes outright rather
    # than asking the form permission a second, stricter time.
    def on_behalf_of_account_allowed?(_resource)
      true
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

      return scope if officer.manage_all?

      officer_group_ids = DeficiencyReport::OfficerGroup.joins(:officers).where(deficiency_report_officers: { id: officer.id }).pluck(:id)

      scope.where(
        "(responsible_type = ? AND responsible_id = ?) OR (responsible_type = ? AND responsible_id IN (?))",
        "DeficiencyReport::Officer", officer.id,
        "DeficiencyReport::OfficerGroup", officer_group_ids
      )
    end
end
