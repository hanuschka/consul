class Adm::Ideas::OfficersController < Adm::Ideas::BaseController
  include Pagy::Backend

  def index
    @pagy, @officers = pagy(
      policy_scope(Idea::Officer, policy_scope_class: Adm::Ideas::OfficerPolicy::Scope)
        .joins(:user)
        .order("users.username ASC")
    )

    @breadcrumbs = [{ name: t("adm.ideas.menu.items.officers"), icon: "badge" }]
  end

  def search
    authorize Idea::Officer, :create?, policy_class: Adm::Ideas::OfficerPolicy
    @user = User.find_by(email: params[:search])

    respond_to do |format|
      if @user
        @officer = Idea::Officer.find_or_initialize_by(user: @user)
        format.turbo_stream
      else
        format.turbo_stream { render "user_not_found" }
      end
    end
  end

  def create
    @officer = Idea::Officer.new(user_id: params[:user_id])
    authorize @officer, policy_class: Adm::Ideas::OfficerPolicy

    @officer.save!
    redirect_to adm_ideas_officers_path
  end

  def destroy
    @officer = Idea::Officer.find(params[:id])
    authorize @officer, policy_class: Adm::Ideas::OfficerPolicy

    @officer.destroy!
    redirect_to adm_ideas_officers_path
  end

  def toggle_manage_all
    @officer = Idea::Officer.find(params[:id])
    authorize @officer, :update?, policy_class: Adm::Ideas::OfficerPolicy

    @officer.update!(manage_all: !@officer.manage_all)
  end
end
