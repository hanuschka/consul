class DeficiencyReportManagement::BaseController < ApplicationController
  layout "admin"

  before_action :set_namespace
  before_action :authenticate_user!
  before_action :verify_deficiency_report_manager
  skip_authorization_check

  private

    def verify_deficiency_report_manager
      raise CanCan::AccessDenied unless current_user&.deficiency_report_manager? ||
        current_user&.administrator?
    end

    def set_namespace
      @namespace = :deficiency_report_management
    end
end
