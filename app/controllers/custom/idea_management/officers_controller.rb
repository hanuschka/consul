class IdeaManagement::OfficersController < IdeaManagement::BaseController
  load_and_authorize_resource :officer, class: "Idea::Officer", except: [:edit, :show]

  def index
    @officers = Idea::Officer.joins(:user).order("users.username ASC").page(params[:page])
  end

  def search
    @user = User.find_by(email: params[:search])

    respond_to do |format|
      if @user
        @officer = Idea::Officer.find_or_initialize_by(user: @user)
        format.js
      else
        format.js { render "user_not_found" }
      end
    end
  end

  def create
    @officer.user_id = params[:user_id]
    @officer.save!

    redirect_to idea_management_officers_path
  end

  def destroy
    @officer.destroy!
    redirect_to idea_management_officers_path
  end
end
