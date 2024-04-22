class Admin::DeficiencyReportManagersController < Admin::BaseController
  load_and_authorize_resource

  def index
    @deficiency_report_managers = @deficiency_report_managers.page(params[:page])
  end

  def search
    @users = User.search(params[:search]).includes(:deficiency_report_manager).page(params[:page])
  end

  def create
    @deficiency_report_manager.user_id = params[:user_id]
    @deficiency_report_manager.save!

    redirect_to admin_deficiency_report_managers_path
  end

  def destroy
    @deficiency_report_manager.destroy!
    redirect_to admin_deficiency_report_managers_path
  end
end
