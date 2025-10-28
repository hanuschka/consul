class Admin::IdeaManagersController < Admin::BaseController
  load_and_authorize_resource

  def index
    @idea_managers = @idea_managers.page(params[:page])
  end

  def search
    @users = User.search(params[:search]).includes(:idea_manager).page(params[:page])
  end

  def create
    @idea_manager.user_id = params[:user_id]
    @idea_manager.save!

    redirect_to admin_idea_managers_path
  end

  def destroy
    @idea_manager.destroy!
    redirect_to admin_idea_managers_path
  end
end
