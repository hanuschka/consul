class DeficiencyReportManagement::BaseController < ApplicationController
  layout "admin"

  include DeficiencyReportsHelper
  helper DeficiencyReportsHelper

  before_action :set_namespace
  before_action :authenticate_user!
  before_action :verify_deficiency_report_manager, unless: :perform_authorization?
  skip_authorization_check unless: :perform_authorization?

  private

    def verify_deficiency_report_manager
      raise CanCan::AccessDenied unless current_user&.deficiency_report_manager? ||
        current_user&.administrator?
    end

    def set_namespace
      @namespace = :deficiency_report_management
    end

    def perform_authorization?
      return false unless current_user&.deficiency_report_officer?

      controllers = %w[deficiency_reports memos]
      controller_name.in? controllers
    end
end
