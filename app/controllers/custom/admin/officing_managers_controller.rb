class Admin::OfficingManagersController < Admin::BaseController
  load_and_authorize_resource

  def index
    @officing_managers = @officing_managers.page(params[:page])
  end

  def search
    @users = User.search(params[:search]).includes(:officing_manager).page(params[:page])
  end

  def create
    @officing_manager.user_id = params[:user_id]
    @officing_manager.save!

    redirect_to admin_officing_managers_path
  end

  def destroy
    @officing_manager.destroy!
    redirect_to admin_officing_managers_path
  end
end
