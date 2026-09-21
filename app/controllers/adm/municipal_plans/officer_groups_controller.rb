class Adm::MunicipalPlans::OfficerGroupsController < Adm::MunicipalPlans::BaseController
  def index
    authorize MunicipalPlan::OfficerGroup, :index?,
      policy_class: Adm::MunicipalPlans::OfficerGroupPolicy

    @officer_groups = policy_scope(
      MunicipalPlan::OfficerGroup,
      policy_scope_class: Adm::MunicipalPlans::OfficerGroupPolicy::Scope
    ).includes(officers: :user).order(:name)

    @breadcrumbs = [{ name: t("adm.municipal_plans.menu.items.officer_groups"), icon: "groups" }]
  end

  def new
    @officer_group = MunicipalPlan::OfficerGroup.new
    authorize @officer_group, policy_class: Adm::MunicipalPlans::OfficerGroupPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @officer_group = MunicipalPlan::OfficerGroup.find(params[:id])
    authorize @officer_group, policy_class: Adm::MunicipalPlans::OfficerGroupPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @officer_group = MunicipalPlan::OfficerGroup.new(officer_group_params)
    authorize @officer_group, policy_class: Adm::MunicipalPlans::OfficerGroupPolicy

    if @officer_group.save
      redirect_to adm_municipal_plans_officer_groups_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.officer_groups.new.title"))
      render :new
    end
  end

  def update
    @officer_group = MunicipalPlan::OfficerGroup.find(params[:id])
    authorize @officer_group, policy_class: Adm::MunicipalPlans::OfficerGroupPolicy

    if @officer_group.update(officer_group_params)
      redirect_to adm_municipal_plans_officer_groups_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.municipal_plans.officer_groups.edit.title"))
      render :edit
    end
  end

  def destroy
    @officer_group = MunicipalPlan::OfficerGroup.find(params[:id])
    authorize @officer_group, policy_class: Adm::MunicipalPlans::OfficerGroupPolicy

    if @officer_group.destroy
      redirect_to adm_municipal_plans_officer_groups_path, notice: t(".success")
    else
      redirect_to adm_municipal_plans_officer_groups_path, alert: t(".cannot_destroy")
    end
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.municipal_plans.officer_groups.index.title"),
          url: adm_municipal_plans_officer_groups_path, icon: "groups" },
        { name: action_title }
      ]
    end

    def officer_group_params
      params.require(:municipal_plan_officer_group).permit(:name, :default_email, officer_ids: [])
    end
end
