class Admin::PollManagersController < Admin::BaseController
  load_and_authorize_resource

  def index
    @poll_managers = @poll_managers.page(params[:page])
  end

  def search
    @users = User.search(params[:search]).includes(:poll_manager).page(params[:page])
  end

  def create
    @poll_manager.user_id = params[:user_id]
    @poll_manager.save!

    redirect_to admin_poll_managers_path
  end

  def destroy
    @poll_manager.destroy!
    redirect_to admin_poll_managers_path
  end
end
