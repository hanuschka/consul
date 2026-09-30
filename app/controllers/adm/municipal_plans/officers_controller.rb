class Adm::MunicipalPlans::OfficersController < Adm::MunicipalPlans::BaseController
  include Pagy::Backend

  def index
    authorize MunicipalPlan::Officer, policy_class: Adm::MunicipalPlans::OfficerPolicy

    @pagy, @officers = pagy(
      policy_scope(MunicipalPlan::Officer, policy_scope_class: Adm::MunicipalPlans::OfficerPolicy::Scope)
        .joins(:user)
        .order("users.username ASC")
    )

    @breadcrumbs = [{ name: t("adm.municipal_plans.menu.items.officers"), icon: "badge" }]
  end

  def search
    authorize MunicipalPlan::Officer, :create?, policy_class: Adm::MunicipalPlans::OfficerPolicy
    @user = User.find_by(email: params[:search])

    respond_to do |format|
      if @user
        @officer = MunicipalPlan::Officer.find_or_initialize_by(user: @user)
        format.turbo_stream
      else
        format.turbo_stream { render "user_not_found" }
      end
    end
  end

  def create
    @officer = MunicipalPlan::Officer.find_or_initialize_by(user_id: params[:user_id])
    authorize @officer, policy_class: Adm::MunicipalPlans::OfficerPolicy

    if @officer.persisted? || @officer.save
      redirect_to adm_municipal_plans_officers_path, notice: t(".success")
    else
      redirect_to adm_municipal_plans_officers_path, alert: @officer.errors.full_messages.to_sentence
    end
  end

  def destroy
    @officer = MunicipalPlan::Officer.find(params[:id])
    authorize @officer, policy_class: Adm::MunicipalPlans::OfficerPolicy

    if @officer.destroy
      redirect_to adm_municipal_plans_officers_path, notice: t(".success")
    else
      redirect_to adm_municipal_plans_officers_path, alert: @officer.errors.full_messages.to_sentence
    end
  end
end
