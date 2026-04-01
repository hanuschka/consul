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
      raise Pundit::NotAuthorizedError unless current_user&.deficiency_report_manager? || current_user&.administrator?
    end

    def authenticate_user!
      redirect_to new_user_session_path unless current_user
    end
end
