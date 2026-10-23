class Adm::MunicipalPlans::MunicipalPlanNoticesController < Adm::MunicipalPlans::BaseController
  def destroy
    municipal_plan = policy_scope(
      MunicipalPlan,
      policy_scope_class: Adm::MunicipalPlans::MunicipalPlanPolicy::Scope
    ).find(params[:municipal_plan_id])
    authorize municipal_plan, :update?, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    municipal_plan.notices.find(params[:id]).destroy!

    redirect_to adm_municipal_plans_municipal_plan_path(municipal_plan), notice: t(".success")
  end
end
