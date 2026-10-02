class Adm::MunicipalPlans::MunicipalPlanAuditsController < Adm::MunicipalPlans::BaseController
  def show
    @municipal_plan = policy_scope(
      MunicipalPlan,
      policy_scope_class: Adm::MunicipalPlans::MunicipalPlanPolicy::Scope
    ).find(params[:municipal_plan_id])
    authorize @municipal_plan, :show?, policy_class: Adm::MunicipalPlans::MunicipalPlanPolicy

    @audit = @municipal_plan.own_and_associated_audits.find(params[:id])
  end
end
